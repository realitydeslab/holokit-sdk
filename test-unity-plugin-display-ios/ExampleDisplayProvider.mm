#include "XR/IUnityXRDisplay.h"
#include "XR/IUnityXRTrace.h"

#include "ProviderContext.h"
#include <cmath>
#include <vector>
#include <iostream>
#include "GetCurrentTime.h"
//#include "Shaders.metal"

// We'll use DX11 to allocate textures if we're on windows.
#if defined(WIN32) || defined(_WIN32) || defined(__WIN32__) || defined(_WIN64) || defined(WINAPI_FAMILY)
#include "D3D11.h"
#include "IUnityGraphicsD3D11.h"
#define XR_DX11 1
#else
#define XR_DX11 0
#endif

#if __APPLE__
#include <TargetConditionals.h>
#define XR_METAL 1
#include "IUnityGraphicsMetal.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#else
#define XR_METAL 0
#endif


#define SIDE_BY_SIDE 1
#define NUM_RENDER_PASSES 2
static const float s_PoseXPositionPerPass[] = {-1.0f, 1.0f};

// BEGIN WORKAROUND: skip first frame since we get invalid data.  Fix coming to trunk.
static bool s_SkipFrame = true;
#define WORKAROUND_SKIP_FIRST_FRAME()           \
    if (s_SkipFrame)                            \
    {                                           \
        s_SkipFrame = false;                    \
        return kUnitySubsystemErrorCodeSuccess; \
    }
#define WORKAROUND_RESET_SKIP_FIRST_FRAME() s_SkipFrame = true;
// END WORKAROUND

id<MTLTexture> loadTextureUsingMetalKit(NSURL * url, id<MTLDevice> device) {
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice: device];
    
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url options:nil error:nil];
    
    if(!texture)
    {
        NSLog(@"Failed to create the texture from %@", url.absoluteString);
        return nil;
    }
    return texture;
}

class ExampleDisplayProvider : ProviderImpl
{
public:
    ExampleDisplayProvider(ProviderContext& ctx, UnitySubsystemHandle handle)
        : ProviderImpl(ctx, handle)
    {
    }

    UnitySubsystemErrorCode Initialize() override;
    UnitySubsystemErrorCode Start() override;

    UnitySubsystemErrorCode GfxThread_Start(UnityXRRenderingCapabilities& renderingCaps);

    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame();
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints& frameHints, UnityXRNextFrameDesc& nextFrame);

    UnitySubsystemErrorCode GfxThread_Stop();
    UnitySubsystemErrorCode GfxThread_FinalBlitToGameViewBackBuffer(const UnityXRMirrorViewBlitInfo* mirrorBlitInfo, ProviderContext& ctx);

    UnitySubsystemErrorCode UpdateDisplayState(UnityXRDisplayState* state, ProviderContext& ctx);
    UnitySubsystemErrorCode QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo* mirrorRtDesc, UnityXRMirrorViewBlitDesc* blitDescriptor, ProviderContext& ctx);

    void Stop() override;
    void Shutdown() override;

private:
    void CreateTextures(int numTextures, int textureArrayLength, float requestedTextureScale);
    void DestroyTextures();

    UnityXRPose GetPose(int pass);
    UnityXRProjection GetProjection(int pass);

private:

    IUnityGraphicsMetal* metalInterface;
    
    bool gotTexture = false;
    bool textureCreated = false;
    
    id<MTLDevice> mtlDevice;
    
    id<MTLTexture> spaceTexture;
#if XR_METAL
    std::vector<void*> m_NativeTextures;
#elif XR_DX11
    std::vector<ID3D11Texture2D*> m_NativeTextures;
#else
    std::vector<void*> m_NativeTextures;
#endif
    std::vector<UnityXRRenderTextureId> m_UnityTextures;
};

UnitySubsystemErrorCode ExampleDisplayProvider::Initialize()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f Initialize()\n", getCurrentTime());
    metalInterface = m_Ctx.interfaces->Get<IUnityGraphicsMetal>();
    
    mtlDevice = metalInterface->MetalDevice();
    NSURL* url = [NSURL URLWithString:@"https://i.stack.imgur.com/9z6nS.png"];
    spaceTexture = loadTextureUsingMetalKit(url, mtlDevice);
    
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::Start()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f Start()\n", getCurrentTime());
    
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::GfxThread_Start(UnityXRRenderingCapabilities& renderingCaps)
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_Start()\n", getCurrentTime());
    
    renderingCaps.noSinglePassRenderingSupport = true; //GetHardwareSupportsLayerIndexInVertexShader();
    
    renderingCaps.skipPresentToMainScreen = false;
    return kUnitySubsystemErrorCodeSuccess;
}

NSString* texShader = @
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "typedef struct {\n"
        "    float4 renderedCoordinate [[position]];\n"
        "    float2 textureCoordinate;\n"
        "} TextureMappingVertex;\n"
        "vertex TextureMappingVertex mapTexture(unsigned int vertex_id [[ vertex_id ]]) {\n"
        "    float4x4 renderedCoordinates = float4x4(float4( -1.0, -1.0, 0.0, 1.0 ),\n"
        "                                            float4(  0.0, -1.0, 0.0, 1.0 ),\n"
        "                                            float4( -1.0,  1.0, 0.0, 1.0 ),\n"
        "                                            float4(  0.0,  1.0, 0.0, 1.0 ));\n"
        "    float4x2 textureCoordinates = float4x2(float2( 0.0, 1.0 ),\n"
        "                                        float2( 1.0, 1.0 ),\n"
        "                                        float2( 0.0, 0.0 ),\n"
        "                                        float2( 1.0, 0.0 ));\n"
        "    TextureMappingVertex outVertex;\n"
        "    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];\n"
        "    outVertex.textureCoordinate = textureCoordinates[vertex_id];\n"
        "    return outVertex;\n"
        "}\n"
        "fragment half4 displayTexture(TextureMappingVertex mappingVertex [[ stage_in ]],\n"
        "                            texture2d<float, access::sample> texture [[ texture(0) ]]) {\n"
        "    constexpr sampler s(address::clamp_to_edge, filter::linear);\n"
        "   return half4(texture.sample(s, mappingVertex.textureCoordinate));\n"
        "}\n";

NSString* shaderStr = @
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "struct AppData\n"
        "{\n"
        "    float4 in_pos [[attribute(0)]];\n"
        "};\n"
        "struct VProgOutput\n"
        "{\n"
        "    float4 out_pos [[position]];\n"
        "    float2 texcoord;\n"
        "};\n"
        "struct FShaderOutput\n"
        "{\n"
        "    half4 frag_data [[color(0)]];\n"
        "};\n"
        "vertex VProgOutput vprog(AppData input [[stage_in]])\n"
        "{\n"
        "    VProgOutput out = { float4(input.in_pos.xy, 0, 1), input.in_pos.zw };\n"
        "    return out;\n"
        "}\n"
        "constexpr sampler blit_tex_sampler(address::clamp_to_edge, filter::linear);\n"
        "fragment FShaderOutput fshader_tex(VProgOutput input [[stage_in]], texture2d<half> tex [[texture(0)]], texture2d<half> tex2 [[texture(1)]])"
        "{\n"
        "    FShaderOutput out = { half4(1,0,0,1) };\n"
        "    if(input.out_pos.x < 1000) {\n"
        "       out = { tex.sample(blit_tex_sampler, input.texcoord) };\n"
        "    } else {\n"
        "       out = { half4(1,0,1,1) };\n"
        "    }\n"
        "    return out;\n"
        "}\n"
        "fragment FShaderOutput fshader_color(VProgOutput input [[stage_in]])\n"
        "{\n"
        "    FShaderOutput out = { half4(1,0,0,1) };\n"
        "    return out;\n"
        "}\n";

const float vdata[] = {
        -1.0f,  1.0f, 0.0f, 0.0f,
        -1.0f, -1.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 1.0f, 1.0f,
        1.0f,  1.0f, 1.0f, 0.0f,
    };

const uint16_t idata[] = {0, 1, 2, 2, 3, 0};

UnitySubsystemErrorCode ExampleDisplayProvider::GfxThread_SubmitCurrentFrame()
{
    // SubmitFrame();
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_SubmitCurrentFrame()\n", getCurrentTime());
    
    id<MTLTexture> texture = metalInterface->CurrentRenderPassDescriptor().colorAttachments[0].texture;
    //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f current render pass texture width:%d, height:%d, pixelFormat:%d, texture type:%d, depth:%d, mipmapLevelCount:%d, sampleCount:%d, arrayLength:%d, resourceOptions:%d, cpuCacheMode:%d, storageMode:%d, hazardTrackingMode:%d, usage:%d, allowGPU:%d, swizzle:%d\n", getCurrentTime(), texture.width, texture.height, texture.pixelFormat, texture.textureType, texture.depth, texture.mipmapLevelCount, texture.sampleCount, texture.arrayLength, texture.resourceOptions, texture.cpuCacheMode, texture.storageMode, texture.hazardTrackingMode, texture.usage, texture.allowGPUOptimizedContents, texture.swizzle);
    
    if(textureCreated == NO) {
        return kUnitySubsystemErrorCodeSuccess;
    }
    // query the texture
    UnityXRRenderTextureDesc unityTextureDesc;
    memset(&unityTextureDesc, 0, sizeof(UnityXRRenderTextureDesc));
    UnitySubsystemErrorCode res = m_Ctx.display->QueryTextureDesc(m_Handle, m_UnityTextures[0], &unityTextureDesc);
    if(res == kUnitySubsystemErrorCodeSuccess) {
        XR_TRACE_LOG(m_Ctx.trace, ">>>>>>>>>> %f query texture succeeded\n", getCurrentTime());
    } else {
        XR_TRACE_LOG(m_Ctx.trace, ">>>>>>>>>> %f query texture failed\n", getCurrentTime());
    }
    XR_TRACE_LOG(m_Ctx.trace, ">>>>>>>>>> %f queried texture width %d and height %d\n", getCurrentTime(), unityTextureDesc.width, unityTextureDesc.height);
    m_NativeTextures[0] = unityTextureDesc.color.nativePtr;
    XR_TRACE_LOG(m_Ctx.trace, ">>>>>>>>>> %f unity texture id %d\n", getCurrentTime(), m_NativeTextures[0]);
    id<MTLTexture> screenTexture = (__bridge id<MTLTexture>)m_NativeTextures[0];
    
    // do an extral draw call
    MTLPixelFormat extraDrawCallPixelFormat = texture.pixelFormat;
    NSUInteger extraDrawCallSampleCount = texture.sampleCount;
    id<MTLLibrary> lib = [mtlDevice newLibraryWithSource:shaderStr options:nil error:nil];
    //id<MTLLibrary> lib = [mtlDevice newDefaultLibrary];
    id<MTLFunction> g_VProg = [lib newFunctionWithName:@"vprog"];
    id<MTLFunction> g_FShaderColor = [lib newFunctionWithName:@"fshader_color"];
    id<MTLFunction> g_FShaderTexture = [lib newFunctionWithName:@"fshader_tex"];
    NSBundle* mtlBundle = metalInterface->MetalBundle();
    MTLVertexDescriptor* g_VertexDesc;
    MTLVertexBufferLayoutDescriptor* streamDesc = [[mtlBundle classNamed:@"MTLVertexBufferLayoutDescriptor"] new];
    streamDesc.stride = 4 * sizeof(float);
    streamDesc.stepFunction = MTLVertexStepFunctionPerVertex;
    streamDesc.stepRate = 1;
    MTLVertexAttributeDescriptor* attrDesc = [[mtlBundle classNamed:@"MTLVertexAttributeDescriptor"] new];
    attrDesc.format = MTLVertexFormatFloat4;
    g_VertexDesc = [[mtlBundle classNamed:@"MTLVertexDescriptor"] vertexDescriptor];
    g_VertexDesc.attributes[0] = attrDesc;
    g_VertexDesc.layouts[0] = streamDesc;
    
    MTLRenderPipelineDescriptor* pipeDesc = [[mtlBundle classNamed:@"MTLRenderPipelineDescriptor"] new];

    MTLRenderPipelineColorAttachmentDescriptor* colorDesc = [[mtlBundle classNamed:@"MTLRenderPipelineColorAttachmentDescriptor"] new];
    colorDesc.pixelFormat = extraDrawCallPixelFormat;
    pipeDesc.colorAttachments[0] = colorDesc;

    //pipeDesc.fragmentFunction = g_FShaderColor;
    pipeDesc.fragmentFunction = g_FShaderTexture;
    pipeDesc.vertexFunction = g_VProg;
    pipeDesc.vertexDescriptor = g_VertexDesc;
    pipeDesc.sampleCount = extraDrawCallSampleCount;
    id<MTLRenderPipelineState> g_ExtraDrawCallPipe = [mtlDevice newRenderPipelineStateWithDescriptor:pipeDesc error:nil];
    
    id<MTLRenderCommandEncoder> cmd = (id<MTLRenderCommandEncoder>)metalInterface->CurrentCommandEncoder();
    [cmd setRenderPipelineState:g_ExtraDrawCallPipe];
    [cmd setCullMode:MTLCullModeNone];
    static id<MTLBuffer> g_VB, g_IB;
    g_VB = [mtlDevice newBufferWithBytes:vdata length:sizeof(vdata) options:MTLResourceOptionCPUCacheModeDefault];
    g_IB = [mtlDevice newBufferWithBytes:idata length:sizeof(idata) options:MTLResourceOptionCPUCacheModeDefault];
    [cmd setVertexBuffer:g_VB offset:0 atIndex:0];
    [cmd setFragmentTexture:screenTexture atIndex:0];
    [cmd setFragmentTexture:screenTexture atIndex:1];
    [cmd drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:g_IB indexBufferOffset:0];
    
    /*
    // draw the texture onto the screen
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.sampleCount = 1;
    pipelineDescriptor.colorAttachments[0].pixelFormat = texture.pixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    //id<MTLLibrary> lib = [mtlDevice newDefaultLibrary];
    id<MTLLibrary> lib = [mtlDevice newLibraryWithSource:texShader options:nil error:nil];
    pipelineDescriptor.vertexFunction = [lib newFunctionWithName:@"mapTexture"];
    pipelineDescriptor.fragmentFunction = [lib newFunctionWithName:@"displayTexture"];
    id<MTLRenderPipelineState> pipelineState = [mtlDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil];
    
    //id<MTLCommandBuffer> commandBuffer = metalInterface->CurrentCommandBuffer();
    //MTLRenderPassDescriptor* rd = metalInterface->CurrentRenderPassDescriptor();
    //id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:rd];
    //[commandEncoder setRenderPipelineState:pipelineState];
    //[commandEncoder setFragmentTexture:texture atIndex:0];
    //[commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
    
    id<MTLRenderCommandEncoder> commandEncoder = (id<MTLRenderCommandEncoder>)metalInterface->CurrentCommandEncoder();
    [commandEncoder setRenderPipelineState:pipelineState];
    [commandEncoder setFragmentTexture:spaceTexture atIndex:0];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
    */
    
    //UnityXRRenderTextureDesc unityTextureDesc;
    //memset(&unityTextureDesc, 0, sizeof(UnityXRRenderTextureDesc));
    
    //UnitySubsystemErrorCode res = m_Ctx.display->QueryTextureDesc(m_Handle, m_UnityTextures[0], &unityTextureDesc);
    //if(res != kUnitySubsystemErrorCodeSuccess) {
    //    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f Failed to query unity texture\n", getCurrentTime());
    //}
    //m_NativeTextures[0] = unityTextureDesc.color.nativePtr;
    //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f Got native texture pointer %x\n", getCurrentTime(), unityTextureDesc.color.nativePtr);
    
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints& frameHints, UnityXRNextFrameDesc& nextFrame)
{
    
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_PopulateNextFrameDesc()\n", getCurrentTime());
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f ReprojectionMode %d\n", getCurrentTime(), frameHints.appSetup.reprojectionMode);
    WORKAROUND_SKIP_FIRST_FRAME();

    // BlockUntilUnityShouldStartSubmittingRenderingCommands();

    
    bool reallocateTextures = (m_UnityTextures.size() == 0);
    if ((kUnityXRFrameSetupHintsChangedSinglePassRendering & frameHints.changedFlags) != 0)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetupHintsChangedSinglePassRendering\n", getCurrentTime());
        reallocateTextures = true;
    }
    if ((kUnityXRFrameSetupHintsChangedRenderViewport & frameHints.changedFlags) != 0)
    {
        // Change sampling UVs for compositor, pass through new viewport on `nextFrame`
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetupHintsChangedRenderViewport\n", getCurrentTime());
    }
    if ((kUnityXRFrameSetupHintsChangedTextureResolutionScale & frameHints.changedFlags) != 0)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetupHintsChangedTextureResolutionScale\n", getCurrentTime());
        reallocateTextures = true;
    }
    if ((kUnityXRFrameSetuphintsChangedContentProtectionState & frameHints.changedFlags) != 0)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetuphintsChangedContentProtectionState\n", getCurrentTime());
        // App wants different content protection mode.
    }
    if ((kUnityXRFrameSetuphintsChangedReprojectionMode & frameHints.changedFlags) != 0)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetuphintsChangedReprojectionMode\n", getCurrentTime());
        // App wants different reprojection mode, configure compositor if possible.
    }
    if ((kUnityXRFrameSetuphintsChangedFocusPlane & frameHints.changedFlags) != 0)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f kUnityXRFrameSetuphintsChangedFocusPlane\n", getCurrentTime());
        // App changed focus plane, configure compositor if possible.
    }

    if (reallocateTextures)
    {
        DestroyTextures();

#if SIDE_BY_SIDE
        int numTextures = 1;
        int textureArrayLength = 0;
#else
        int numTextures = frameHints.appSetup.singlePassRendering ? NUM_RENDER_PASSES - 1 : NUM_RENDER_PASSES;
        int textureArrayLength = frameHints.appSetup.singlePassRendering ? 2 : 0;
#endif
        CreateTextures(numTextures, textureArrayLength, frameHints.appSetup.textureResolutionScale);
    }

    // Frame hints tells us if we should setup our renderpasses with a single pass
    if (!frameHints.appSetup.singlePassRendering)
    {
        XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_PopulateNextFrameDesc Use multi-pass rendering to render %d ()\n", getCurrentTime(), NUM_RENDER_PASSES);

        // Use multi-pass rendering to render

        // Can increase render pass count to do wide FOV or to have a separate view into scene.
        nextFrame.renderPassesCount = NUM_RENDER_PASSES;

        for (int pass = 0; pass < nextFrame.renderPassesCount; ++pass)
        {
            auto& renderPass = nextFrame.renderPasses[pass];

            // Texture that unity will render to next frame.  We created it above.
            // You might want to change this dynamically to double / triple buffer.
#if !SIDE_BY_SIDE
            renderPass.textureId = m_UnityTextures[pass];
#else
            renderPass.textureId = m_UnityTextures[0];
#endif

            // One set of render params per pass.
            renderPass.renderParamsCount = 1;

            // Note that you can share culling between multiple passes by setting this to the same index.
            renderPass.cullingPassIndex = pass;

            // Fill out render params. View, projection, viewport for pass.
            auto& cullingPass = nextFrame.cullingPasses[pass];
            cullingPass.separation = fabs(s_PoseXPositionPerPass[1]) + fabs(s_PoseXPositionPerPass[0]);

            auto& renderParams = renderPass.renderParams[0];
            renderParams.deviceAnchorToEyePose = cullingPass.deviceAnchorToCullingPose = GetPose(pass);
            renderParams.projection = cullingPass.projection = GetProjection(pass);

#if !SIDE_BY_SIDE
            // App has hinted that it would like to render to a smaller viewport.  Tell unity to render to that viewport.
            renderParams.viewportRect = frameHints.appSetup.renderViewport;

            // Tell the compositor what pixels were rendered to for display.
            // Compositor_SetRenderSubRect(pass, renderParams.viewportRect);
#else
            // TODO: frameHints.appSetup.renderViewport
            renderParams.viewportRect = {
                pass == 0 ? 0.0f : 0.5f, // x
                0.0f,                    // y
                0.5f,                    // width
                1.0f                     // height
            };
#endif
        }
    }
    else
    {
        // Example of using single-pass stereo to combine the first two render passes.
        nextFrame.renderPassesCount = NUM_RENDER_PASSES - 1;

        UnityXRNextFrameDesc::UnityXRRenderPass& renderPass = nextFrame.renderPasses[0];

        // Texture that unity will render to next frame.  We created it above.
        // You might want to change this dynamically to double / triple buffer.
        renderPass.textureId = m_UnityTextures[0];

        // Two sets of render params for first pass, view / projection for each eye.  Fill them out next.
        renderPass.renderParamsCount = 2;

        for (int eye = 0; eye < 2; ++eye)
        {
            UnityXRNextFrameDesc::UnityXRRenderPass::UnityXRRenderParams& renderParams = renderPass.renderParams[eye];
            renderParams.deviceAnchorToEyePose = GetPose(eye);
            renderParams.projection = GetProjection(eye);

#if SIDE_BY_SIDE
            // TODO: frameHints.appSetup.renderViewport
            renderParams.viewportRect = {
                eye == 0 ? 0.2f : 0.7f, // x
                0.4f,                   // y
                0.2f,                   // width
                0.3f                    // height
            };
#else
            // Each eye goes to different texture array slices.
            renderParams.textureArraySlice = eye;
#endif
        }
        
        renderPass.cullingPassIndex = 0;

        // TODO: set up culling pass to use a combine frustum
        auto& cullingPass = nextFrame.cullingPasses[0];
        cullingPass.deviceAnchorToCullingPose = GetPose(0);
        cullingPass.projection = GetProjection(0);
        cullingPass.separation = 0.625f;
    }
    
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::GfxThread_Stop()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_Stop()\n", getCurrentTime());
    
    WORKAROUND_RESET_SKIP_FIRST_FRAME();
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::GfxThread_FinalBlitToGameViewBackBuffer(const UnityXRMirrorViewBlitInfo* mirrorBlitInfo, ProviderContext& ctx)
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_FinalBlitToGameViewBackBuffer()\n", getCurrentTime());
    
#if XR_DX11
    ID3D11Device* dxDevice = ctx.interfaces->Get<IUnityGraphicsD3D11>()->GetDevice();
    ID3D11RenderTargetView* rtv = ctx.interfaces->Get<IUnityGraphicsD3D11>()->RTVFromRenderBuffer(mirrorBlitInfo->mirrorRtDesc->rtNative);
    ID3D11DeviceContext* immContext;
    dxDevice->GetImmediateContext(&immContext);

    immContext->OMSetRenderTargets(1, &rtv, NULL);
    // clear to blue
    const FLOAT clrColor[4] = {0, 0, 1, 1};
    immContext->ClearRenderTargetView(rtv, clrColor);
#endif

    return UnitySubsystemErrorCode::kUnitySubsystemErrorCodeSuccess;
}

void ExampleDisplayProvider::Stop()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f Stop()\n", getCurrentTime());
}

void ExampleDisplayProvider::Shutdown()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< Shutdown()\n");
}

void ExampleDisplayProvider::CreateTextures(int numTextures, int textureArrayLength, float requestedTextureScale)
{
    //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f CreateTextures()\n", getCurrentTime());
    
    const int texWidth = 2778; //(int)(1920.0f * requestedTextureScale * (SIDE_BY_SIDE ? 2.0f : 1.0f));
    const int texHeight = 1284; //(int)(1200.0f * requestedTextureScale);
    //const int texWidth = (int)(1920.0f * requestedTextureScale * (SIDE_BY_SIDE ? 2.0f : 1.0f));
    //const int texHeight = (int)(1200.0f * requestedTextureScale);
    
    m_NativeTextures.resize(numTextures);
    m_UnityTextures.resize(numTextures);

    // Tell unity about the native textures, getting back UnityXRRenderTextureIds.
    for (int i = 0; i < numTextures; ++i)
    {
        UnityXRRenderTextureDesc uDesc;
        memset(&uDesc, 0 , sizeof(UnityXRRenderTextureDesc));
#if XR_METAL
        //IUnityGraphicsMetal* metalInterface = m_Ctx.interfaces->Get<IUnityGraphicsMetal>();
        //id<MTLDevice> mtlDevice = metalInterface->MetalDevice();
        //id<MTLTexture> tex = metalInterface->cu
        NSLog(@"----------------------");
        NSLog(@"%@", mtlDevice.name);
        NSLog(@"----------------------");
        
        //MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
        MTLTextureDescriptor* textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:texWidth height:texHeight mipmapped:NO];
        textureDesc.textureType = MTLTextureType2D;
        textureDesc.depth = 1;
        textureDesc.mipmapLevelCount = 1;
        textureDesc.sampleCount = 1;
        textureDesc.arrayLength = 1;
        textureDesc.resourceOptions = 512;
        textureDesc.cpuCacheMode = (MTLCPUCacheMode)0;
        textureDesc.storageMode = (MTLStorageMode)0;
        textureDesc.hazardTrackingMode = (MTLHazardTrackingMode)2;
        textureDesc.usage = 23;
        textureDesc.allowGPUOptimizedContents = 1;
        //textureDesc.swizzle = MTLTextureSwizzleRed;
        id<MTLTexture> nativeTex = [mtlDevice newTextureWithDescriptor:textureDesc];
        
        //reinterpret_cast<void*>(static_cast<intptr_t>(i))
        
        //m_NativeTextures[i] = nativeTex;
        //uDesc.color.nativePtr = nativeTex;
        uDesc.color.nativePtr = (__bridge void*)nativeTex;
        
        uDesc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
        //NSLog(@"@", uDesc.color.nativePtr);
        //NSLog(@"--------------------------------------");
#elif XR_DX11
        // Example of your compositor creating textures for unity to render in to.
        ID3D11Device* dxDevice = m_Ctx.interfaces->Get<IUnityGraphicsD3D11>()->GetDevice();
        D3D11_TEXTURE2D_DESC dxDesc = CD3D11_TEXTURE2D_DESC(DXGI_FORMAT_R8G8B8A8_UNORM, texWidth, texHeight);
        dxDesc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
        dxDesc.ArraySize = (textureArrayLength == 0 ? 1 : textureArrayLength);
        ID3D11Texture2D* nativeTex;
        dxDevice->CreateTexture2D(&dxDesc, NULL, &nativeTex);
        m_NativeTextures[i] = nativeTex;

        uDesc.color.nativePtr = nativeTex;
#else
        // Example of telling Unity to create the texture.  You can later obtain the native texture resource with
        // QueryTextureDesc
        uDesc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
#endif
        
        
        uDesc.width = texWidth;
        uDesc.height = texHeight;
        uDesc.textureArrayLength = textureArrayLength;

        // Create an UnityXRRenderTextureId for the native texture so we can tell unity to render to it later.
        UnityXRRenderTextureId uTexId;
        m_Ctx.display->CreateTexture(m_Handle, &uDesc, &uTexId);
        m_UnityTextures[i] = uTexId;
    }
    XR_TRACE_LOG(m_Ctx.trace, ">>>>>>>>>> %f CreateTextures()\n", getCurrentTime());
    textureCreated = true;
}

void ExampleDisplayProvider::DestroyTextures()
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f DestroyTextures()\n", getCurrentTime());
    
#if XR_DX11 || XR_METAL
    assert(m_NativeTextures.size() == m_UnityTextures.size());
#endif

    for (int i = 0; i < m_UnityTextures.size(); ++i)
    {
        if (m_UnityTextures[i] != 0)
        {
            m_Ctx.display->DestroyTexture(m_Handle, m_UnityTextures[i]);
#if XR_METAL
            m_NativeTextures[i] = nullptr;
#elif XR_DX11
            m_NativeTextures[i]->Release();
#endif
        }
    }

    m_UnityTextures.clear();
    m_NativeTextures.clear();
}

UnityXRPose ExampleDisplayProvider::GetPose(int pass)
{
    UnityXRPose pose{};
    if (pass < (sizeof(s_PoseXPositionPerPass) / sizeof(s_PoseXPositionPerPass[0])))
        pose.position.x = s_PoseXPositionPerPass[pass];
    pose.position.z = -10.0f;
    pose.rotation.w = 1.0f;
    return pose;
}

UnityXRProjection ExampleDisplayProvider::GetProjection(int pass)
{
    UnityXRProjection ret;
    ret.type = kUnityXRProjectionTypeHalfAngles;
    ret.data.halfAngles.left = -1.0;
    ret.data.halfAngles.right = 1.0;
    ret.data.halfAngles.top = 0.625;
    ret.data.halfAngles.bottom = -0.625;
    return ret;
}

UnitySubsystemErrorCode ExampleDisplayProvider::UpdateDisplayState(UnityXRDisplayState * state, ProviderContext &ctx) {
    
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f UpdateDisplayState()\n", getCurrentTime());
    
    state->displayIsTransparent = true;
    state->reprojectionMode = kUnityXRReprojectionModeUnspecified;
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f reprojectionMode %d\n", getCurrentTime(), state->reprojectionMode);
    state->focusLost = false;
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode ExampleDisplayProvider::QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo* mirrorBlitInfo, UnityXRMirrorViewBlitDesc* blitDescriptor, ProviderContext& ctx)
{
    XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f QueryMirrorViewBlitDesc()\n", getCurrentTime());
    
    if (ctx.displayProvider->m_UnityTextures.size() == 0)
    {
        // Eye texture is not available yet, return failure
        return UnitySubsystemErrorCode::kUnitySubsystemErrorCodeFailure;
    }
    // atw
    int srcTexId = ctx.displayProvider->m_UnityTextures[0];
    const UnityXRVector2 sourceTextureSize = {static_cast<float>(1920), static_cast<float>(1200)};
    const UnityXRRectf sourceUVRect = {0.0f, 0.0f, 1.0f, 1.0f};
    const UnityXRVector2 destTextureSize = {static_cast<float>(mirrorBlitInfo->mirrorRtDesc->rtScaledWidth), static_cast<float>(mirrorBlitInfo->mirrorRtDesc->rtScaledHeight)};
    const UnityXRRectf destUVRect = {0.0f, 0.0f, 1.0f, 1.0f};

    // By default, The source rect will be adjust so that it matches the dest rect aspect ratio.
    // This has the visual effect of expanding the source image, resulting in cropping
    // along the non-fitting axis. In this mode, the destination rect will be completely
    // filled, but not all the source image may be visible.
    UnityXRVector2 sourceUV0, sourceUV1, destUV0, destUV1;

    float sourceAspect = (sourceTextureSize.x * sourceUVRect.width) / (sourceTextureSize.y * sourceUVRect.height);
    float destAspect = (destTextureSize.x * destUVRect.width) / (destTextureSize.y * destUVRect.height);
    float ratio = sourceAspect / destAspect;
    UnityXRVector2 sourceUVCenter = {sourceUVRect.x + sourceUVRect.width * 0.5f, sourceUVRect.y + sourceUVRect.height * 0.5f};
    UnityXRVector2 sourceUVSize = {sourceUVRect.width, sourceUVRect.height};
    UnityXRVector2 destUVCenter = {destUVRect.x + destUVRect.width * 0.5f, destUVRect.y + destUVRect.height * 0.5f};
    UnityXRVector2 destUVSize = {destUVRect.width, destUVRect.height};

    if (ratio > 1.0f)
    {
        sourceUVSize.x /= ratio;
    }
    else
    {
        sourceUVSize.y *= ratio;
    }

    sourceUV0 = {sourceUVCenter.x - (sourceUVSize.x * 0.5f), sourceUVCenter.y - (sourceUVSize.y * 0.5f)};
    sourceUV1 = {sourceUV0.x + sourceUVSize.x, sourceUV0.y + sourceUVSize.y};
    destUV0 = {destUVCenter.x - destUVSize.x * 0.5f, destUVCenter.y - destUVSize.y * 0.5f};
    destUV1 = {destUV0.x + destUVSize.x, destUV0.y + destUVSize.y};

    (*blitDescriptor).blitParamsCount = 1;
    (*blitDescriptor).blitParams[0].srcTexId = srcTexId;
    (*blitDescriptor).blitParams[0].srcTexArraySlice = 0;
    (*blitDescriptor).blitParams[0].srcRect = {sourceUV0.x, sourceUV0.y, sourceUV1.x - sourceUV0.x, sourceUV1.y - sourceUV0.y};
    (*blitDescriptor).blitParams[0].destRect = {destUV0.x, destUV0.y, destUV1.x - destUV0.x, destUV1.y - destUV0.y};
    
    return kUnitySubsystemErrorCodeFailure;
    return kUnitySubsystemErrorCodeSuccess;
}

// Binding to C-API below here

static UnitySubsystemErrorCode UNITY_INTERFACE_API Display_Initialize(UnitySubsystemHandle handle, void* userData)
{
    
    auto& ctx = GetProviderContext(userData);
    
    XR_TRACE_LOG(ctx.trace, "<<<<<<<<<< %f Display_Initialize()\n", getCurrentTime());

    ctx.displayProvider = new ExampleDisplayProvider(ctx, handle);

    // Register for callbacks on the graphics thread.
    UnityXRDisplayGraphicsThreadProvider gfxThreadProvider{};
    gfxThreadProvider.userData = &ctx;

    gfxThreadProvider.Start = [](UnitySubsystemHandle handle, void* userData, UnityXRRenderingCapabilities* renderingCaps) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_Start(*renderingCaps);
    };

    gfxThreadProvider.SubmitCurrentFrame = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_SubmitCurrentFrame();
    };

    gfxThreadProvider.PopulateNextFrameDesc = [](UnitySubsystemHandle handle, void* userData, const UnityXRFrameSetupHints* frameHints, UnityXRNextFrameDesc* nextFrame) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_PopulateNextFrameDesc(*frameHints, *nextFrame);
    };

    gfxThreadProvider.Stop = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_Stop();
    };

    gfxThreadProvider.BlitToMirrorViewRenderTarget = [](UnitySubsystemHandle handle, void* userData, const UnityXRMirrorViewBlitInfo mirrorBlitInfo) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_FinalBlitToGameViewBackBuffer(&mirrorBlitInfo, ctx);
    };

    ctx.display->RegisterProviderForGraphicsThread(handle, &gfxThreadProvider);

    UnityXRDisplayProvider provider{&ctx, NULL, NULL};
    
    provider.UpdateDisplayState = [](UnitySubsystemHandle handle, void* userData, UnityXRDisplayState * state) ->UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->UpdateDisplayState(state, ctx);
    };
    
    provider.QueryMirrorViewBlitDesc = [](UnitySubsystemHandle handle, void* userData, const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc* blitDescriptor) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->QueryMirrorViewBlitDesc(&mirrorBlitInfo, blitDescriptor, ctx);
    };

    ctx.display->RegisterProvider(handle, &provider);

    return ctx.displayProvider->Initialize();
}

UnitySubsystemErrorCode Load_Display(ProviderContext& ctx)
{
    XR_TRACE_LOG(ctx.trace, "<<<<<<<<<< %f Load_Display()\n", getCurrentTime());
    
    ctx.display = ctx.interfaces->Get<IUnityXRDisplayInterface>();
    if (ctx.display == NULL)
        return kUnitySubsystemErrorCodeFailure;

    UnityLifecycleProvider displayLifecycleHandler{};
    displayLifecycleHandler.userData = &ctx;
    displayLifecycleHandler.Initialize = &Display_Initialize;

    displayLifecycleHandler.Start = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->Start();
    };

    displayLifecycleHandler.Stop = [](UnitySubsystemHandle handle, void* userData) -> void {
        auto& ctx = GetProviderContext(userData);
        ctx.displayProvider->Stop();
    };

    displayLifecycleHandler.Shutdown = [](UnitySubsystemHandle handle, void* userData) -> void {
        auto& ctx = GetProviderContext(userData);
        ctx.displayProvider->Shutdown();
        delete ctx.displayProvider;
    };

    return ctx.display->RegisterLifecycleProvider("XR SDK Display Sample", "Display Sample", &displayLifecycleHandler);
}
