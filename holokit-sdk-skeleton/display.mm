//
//  display.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <memory>
#include <vector>

#include "IUnityXRTrace.h"
#include "IUnityXRDisplay.h"
#include "UnitySubsystemTypes.h"
#include "load.h"
#include "math_helpers.h"
#include "holokit_xr_unity.h"

#if __APPLE__
#define XR_METAL 1
#define XR_ANDROID 0
#include "IUnityGraphicsMetal.h"
#include <Metal/Metal.h>
#else
#define XR_METAL 0
#define XR_ANDROID 1
#endif

/// If this is 1, both render passes will render to a single texture.
/// Otherwise, they will render to two separate textures.
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

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitDisplayProvider]: " message "\n", \
               ##__VA_ARGS__)

// TODO: put the following data in a proper place
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
        "    if(input.out_pos.x < tex.get_width() / 2) {\n"
        "       //input.texcoord.x *= 2;\n"
        "       out = { tex.sample(blit_tex_sampler, input.texcoord) };\n"
        "    } else {\n"
        "       //input.texcoord.x = (input.texcoord.x - 0.5) * 2;\n"
        "       out = { tex2.sample(blit_tex_sampler, input.texcoord) };\n"
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

namespace {
class HoloKitDisplayProvider {
public:
    HoloKitDisplayProvider(IUnityXRTrace* trace,
                           IUnityXRDisplayInterface* display)
        : trace_(trace), display_(display) {}
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    IUnityXRDisplayInterface* GetDisplay() { return display_; }
    
    void SetHandle(UnitySubsystemHandle handle) { handle_ = handle; }
    
    void SetMtlDevice(id<MTLDevice> device) { mtl_device_ = device; }
    
    void SetNSBundle(NSBundle* bundle) { mtl_bundle_ = bundle; }
    
    void SetMtlInterface(IUnityGraphicsMetal* mtl_interface) { metal_interface_ = mtl_interface; }
    
    ///@return A reference to the static instance of this singleton class.
    static std::unique_ptr<HoloKitDisplayProvider>& GetInstance();

#pragma mark - Display Provider Methods
    /// @brief Initializes the display subsystem.
    ///
    /// @details Loads and configures a UnityXRDisplayGraphicsThreadProvider and
    ///         UnityXRDisplayProvider with pointers to `display_provider_`'s methods.
    /// @param handle Opaque Unity pointer type passed between plugins.
    /// @return kUnitySubsystemErrorCodeSuccess when the registration is
    ///         successful. Otherwise, a value in UnitySubsystemErrorCode flagging
    ///         the error.
    UnitySubsystemErrorCode Initialize(UnitySubsystemHandle handle) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Initialize()", GetCurrentTime());
        
        SetHandle(handle);
        
        // Register for callbacks on the graphics thread.
        UnityXRDisplayGraphicsThreadProvider gfx_thread_provider{};
        gfx_thread_provider.userData = NULL;
        gfx_thread_provider.Start = [](UnitySubsystemHandle, void*, UnityXRRenderingCapabilities* rendering_caps) -> UnitySubsystemErrorCode {
            return GetInstance()->GfxThread_Start(rendering_caps);
        };
        gfx_thread_provider.SubmitCurrentFrame = [](UnitySubsystemHandle, void*) -> UnitySubsystemErrorCode {
            return GetInstance()->GfxThread_SubmitCurrentFrame();
        };
        gfx_thread_provider.PopulateNextFrameDesc = []
        (UnitySubsystemHandle, void*, const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) -> UnitySubsystemErrorCode {
            return GetInstance()->GfxThread_PopulateNextFrameDesc(frame_hints, next_frame);
        };
        gfx_thread_provider.Stop = [](UnitySubsystemHandle, void*) -> UnitySubsystemErrorCode {
            return GetInstance()->GfxThread_Stop();
        };
        GetInstance()->GetDisplay()->RegisterProviderForGraphicsThread
        (handle, &gfx_thread_provider);
        
        // Register for callbacks on display provider.
        UnityXRDisplayProvider provider{NULL, NULL, NULL};
        provider.UpdateDisplayState = [](UnitySubsystemHandle, void*, UnityXRDisplayState* state) -> UnitySubsystemErrorCode {
            return GetInstance()->UpdateDisplayState(state);
        };
        provider.QueryMirrorViewBlitDesc = [](UnitySubsystemHandle, void*, const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc * blitDescriptor) -> UnitySubsystemErrorCode {
            return GetInstance()->QueryMirrorViewBlitDesc(mirrorBlitInfo, blitDescriptor);
        };
        GetInstance()->GetDisplay()->RegisterProvider(handle, &provider);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode Start() const {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Start()", GetCurrentTime());
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop() const {}
    
    void Shutdown() const {}
    
    UnitySubsystemErrorCode UpdateDisplayState(UnityXRDisplayState* state) {
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc * blitDescriptor) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f QueryMirrorViewBlitDesc()", GetCurrentTime());
        
        // TODO: fill this
        if (unity_textures_.size() == 0)
        {
            // Eye texture is not available yet, return failure
            return UnitySubsystemErrorCode::kUnitySubsystemErrorCodeFailure;
        }
        // atw
        int srcTexId = unity_textures_[0];
        const UnityXRVector2 sourceTextureSize = {static_cast<float>(1920), static_cast<float>(1200)};
        const UnityXRRectf sourceUVRect = {0.0f, 0.0f, 1.0f, 1.0f};
        const UnityXRVector2 destTextureSize = {static_cast<float>(mirrorBlitInfo.mirrorRtDesc->rtScaledWidth), static_cast<float>(mirrorBlitInfo.mirrorRtDesc->rtScaledHeight)};
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
        
        // currently we do not need blit
        //return kUnitySubsystemErrorCodeSuccess;
        return kUnitySubsystemErrorCodeFailure;
    }
    
#pragma mark - Gfx Thread Provider Methods
    UnitySubsystemErrorCode GfxThread_Start(
            UnityXRRenderingCapabilities* rendering_caps) const {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_Start()", GetCurrentTime());
        // Does the system use multi-pass rendering?
        rendering_caps->noSinglePassRenderingSupport = true;
        rendering_caps->invalidateRenderStateAfterEachCallback = true;
        // Unity will swap buffers for us after GfxThread_SubmitCurrentFrame()
        // is executed.
        rendering_caps->skipPresentToMainScreen = false;
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    /*
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_SubmitCurrentFrame()", GetCurrentTime());
        // TODO: should we get native textures here?
        if(!textures_initialized_) {
            return kUnitySubsystemErrorCodeSuccess;
        }
        
        if (!native_textures_got_) {
            // Query left eye texture
            UnityXRRenderTextureDesc unity_texture_desc;
            memset(&unity_texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            UnitySubsystemErrorCode query_result = display_->QueryTextureDesc(handle_, unity_textures_[0], &unity_texture_desc);
            if (query_result == kUnitySubsystemErrorCodeSuccess) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query succeeded()", GetCurrentTime());
                NSLog(@"native texture pointer id: %d", unity_texture_desc.color.nativePtr);
            } else {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query failed()", GetCurrentTime());
            }
            native_textures_[0] = unity_texture_desc.color.nativePtr;
            metal_textures_[0] = (__bridge id<MTLTexture>)native_textures_[0];
            
            // TODO: query the right eye texture when SIDE_BY_SIDE = 0
            native_textures_got_ = true;
        }
        
        id<MTLLibrary> lib = [mtl_device_ newLibraryWithSource:shaderStr options:nil error:nil];
        id<MTLFunction> vertex_function = [lib newFunctionWithName:@"vprog"];
        id<MTLFunction> fragment_function = [lib newFunctionWithName:@"fshader_tex"];
        MTLVertexDescriptor* g_VertexDesc;
        MTLVertexBufferLayoutDescriptor* streamDesc = [[mtl_bundle_ classNamed:@"MTLVertexBufferLayoutDescriptor"] new];
        streamDesc.stride = 4 * sizeof(float);
        streamDesc.stepFunction = MTLVertexStepFunctionPerVertex;
        streamDesc.stepRate = 1;
        MTLVertexAttributeDescriptor* attrDesc = [[mtl_bundle_ classNamed:@"MTLVertexAttributeDescriptor"] new];
        attrDesc.format = MTLVertexFormatFloat4;
        g_VertexDesc = [[mtl_bundle_ classNamed:@"MTLVertexDescriptor"] vertexDescriptor];
        g_VertexDesc.attributes[0] = attrDesc;
        g_VertexDesc.layouts[0] = streamDesc;
        
        MTLRenderPipelineDescriptor* pipeDesc = [[mtl_bundle_ classNamed:@"MTLRenderPipelineDescriptor"] new];

        MTLRenderPipelineColorAttachmentDescriptor* colorDesc = [[mtl_bundle_ classNamed:@"MTLRenderPipelineColorAttachmentDescriptor"] new];
        colorDesc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipeDesc.colorAttachments[0] = colorDesc;

        //pipeDesc.fragmentFunction = g_FShaderColor;
        pipeDesc.fragmentFunction = fragment_function;
        pipeDesc.vertexFunction = vertex_function;
        pipeDesc.vertexDescriptor = g_VertexDesc;
        pipeDesc.sampleCount = 1;
        id<MTLRenderPipelineState> g_ExtraDrawCallPipe = [mtl_device_ newRenderPipelineStateWithDescriptor:pipeDesc error:nil];
        
        id<MTLRenderCommandEncoder> cmd = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [cmd setRenderPipelineState:g_ExtraDrawCallPipe];
        [cmd setCullMode:MTLCullModeNone];
        static id<MTLBuffer> g_VB, g_IB;
        g_VB = [mtl_device_ newBufferWithBytes:vdata length:sizeof(vdata) options:MTLResourceOptionCPUCacheModeDefault];
        g_IB = [mtl_device_ newBufferWithBytes:idata length:sizeof(idata) options:MTLResourceOptionCPUCacheModeDefault];
        [cmd setVertexBuffer:g_VB offset:0 atIndex:0];
        [cmd setFragmentTexture:metal_textures_[0] atIndex:0];
        [cmd setFragmentTexture:metal_textures_[0] atIndex:1];
        [cmd drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:g_IB indexBufferOffset:0];
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    */
    // TODO: delete this
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame()
    {
        // SubmitFrame();
        //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f GfxThread_SubmitCurrentFrame()\n", getCurrentTime());
        //return kUnitySubsystemErrorCodeSuccess;
        //id<MTLTexture> texture = metal_interface_->CurrentRenderPassDescriptor().colorAttachments[0].texture;
        //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f current render pass texture width:%d, height:%d, pixelFormat:%d, texture type:%d, depth:%d, mipmapLevelCount:%d, sampleCount:%d, arrayLength:%d, resourceOptions:%d, cpuCacheMode:%d, storageMode:%d, hazardTrackingMode:%d, usage:%d, allowGPU:%d, swizzle:%d\n", getCurrentTime(), texture.width, texture.height, texture.pixelFormat, texture.textureType, texture.depth, texture.mipmapLevelCount, texture.sampleCount, texture.arrayLength, texture.resourceOptions, texture.cpuCacheMode, texture.storageMode, texture.hazardTrackingMode, texture.usage, texture.allowGPUOptimizedContents, texture.swizzle);
        
        
        if(textures_initialized_ == NO) {
            return kUnitySubsystemErrorCodeSuccess;
        }
        if(native_textures_got_ == NO) {
            // Query left eye texture
            UnityXRRenderTextureDesc unity_texture_desc;
            memset(&unity_texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            UnitySubsystemErrorCode query_result = display_->QueryTextureDesc(handle_, unity_textures_[0], &unity_texture_desc);
            if (query_result == kUnitySubsystemErrorCodeSuccess) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query succeeded()", GetCurrentTime());
                NSLog(@"native texture pointer id: %d", unity_texture_desc.color.nativePtr);
            } else {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query failed()", GetCurrentTime());
            }
            native_textures_[0] = unity_texture_desc.color.nativePtr;
            metal_textures_[0] = (__bridge id<MTLTexture>)native_textures_[0];
            // TODO: query the right eye texture when SIDE_BY_SIDE = 0
            
            native_textures_got_ = true;
        }
        
        // do an extral draw call
        //MTLPixelFormat extraDrawCallPixelFormat = texture.pixelFormat;
        //NSUInteger extraDrawCallSampleCount = texture.sampleCount;
        id<MTLLibrary> lib = [mtl_device_ newLibraryWithSource:shaderStr options:nil error:nil];
        //id<MTLLibrary> lib = [mtlDevice newDefaultLibrary];
        id<MTLFunction> g_VProg = [lib newFunctionWithName:@"vprog"];
        id<MTLFunction> g_FShaderColor = [lib newFunctionWithName:@"fshader_color"];
        id<MTLFunction> g_FShaderTexture = [lib newFunctionWithName:@"fshader_tex"];
        NSBundle* mtlBundle = metal_interface_->MetalBundle();
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
        colorDesc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipeDesc.colorAttachments[0] = colorDesc;

        //pipeDesc.fragmentFunction = g_FShaderColor;
        pipeDesc.fragmentFunction = g_FShaderTexture;
        pipeDesc.vertexFunction = g_VProg;
        pipeDesc.vertexDescriptor = g_VertexDesc;
        pipeDesc.sampleCount = 1;
        id<MTLRenderPipelineState> g_ExtraDrawCallPipe = [mtl_device_ newRenderPipelineStateWithDescriptor:pipeDesc error:nil];
        
        id<MTLRenderCommandEncoder> cmd = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [cmd setRenderPipelineState:g_ExtraDrawCallPipe];
        [cmd setCullMode:MTLCullModeNone];
        static id<MTLBuffer> g_VB, g_IB;
        g_VB = [mtl_device_ newBufferWithBytes:vdata length:sizeof(vdata) options:MTLResourceOptionCPUCacheModeDefault];
        g_IB = [mtl_device_ newBufferWithBytes:idata length:sizeof(idata) options:MTLResourceOptionCPUCacheModeDefault];
        [cmd setVertexBuffer:g_VB offset:0 atIndex:0];
        [cmd setFragmentTexture:metal_textures_[0] atIndex:0];
        [cmd setFragmentTexture:metal_textures_[0] atIndex:1];
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
    
    /*
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()", GetCurrentTime());
        WORKAROUND_SKIP_FIRST_FRAME();
        
        // Allocate new textures if needed
        if((frame_hints->changedFlags & kUnityXRFrameSetupHintsChangedTextureResolutionScale) != 0 || (frame_hints->changedFlags & kUnityXRFrameSetupHintsChangedSinglePassRendering) != 0 || !is_initialized_) {
            // TODO: reset HoloKitApi
            
            // Deallocate old textures
            DestroyTextures();
            
            // Create new textures
#if SIDE_BY_SIDE
            int num_textures = 1;
            int texture_array_length = 0;
#else
            int num_textures = 2;
            // TODO: for single pass rendering, it seems that this should be 2
            int texture_array_length = 0;
#endif
            CreateTextures(num_textures, texture_array_length, frame_hints->appSetup.textureResolutionScale);
        }
        
        // use multi-pass rendering or single-pass rendering?
        if (!frame_hints->appSetup.singlePassRendering) {
            // multi-pass rendering
            next_frame->renderPassesCount = 2;
            
            for (int pass = 0; pass < next_frame->renderPassesCount; pass++){
                // get a reference of the current render pass
                auto& render_pass = next_frame->renderPasses[pass];
                
#if SIDE_BY_SIDE
                // for both passes, we render the content to a single texture
                // through two different viewports
                render_pass.textureId = unity_textures_[0];
#else
                // each pass renders to a separate texture
                render_pass.textureId = unity_textures_[pass];
#endif
                
                render_pass.renderParamsCount = 1;
                
                // we can also share the culling pass between two render passes
                render_pass.cullingPassIndex = pass;
                
                auto& culling_pass = next_frame->cullingPasses[pass];
                // TODO: culling pass seperation
    
                // set view and projection matrices
                auto& render_params = render_pass.renderParams[0];
                render_params.deviceAnchorToEyePose = culling_pass.deviceAnchorToCullingPose = holokit_api_->GetViewMatrix(pass);
                //render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
                //render_params.projection.data.matrix = culling_pass.projection.data.matrix = holokit_api_->GetProjectionMatrix(pass);
                
                // test
                UnityXRProjection ret;
                ret.type = kUnityXRProjectionTypeHalfAngles;
                ret.data.halfAngles.left = -1.0;
                ret.data.halfAngles.right = 1.0;
                ret.data.halfAngles.top = 0.625;
                ret.data.halfAngles.bottom = -0.625;
                render_params.projection = culling_pass.projection = ret;
                
#if SIDE_BY_SIDE
                render_params.viewportRect = {
                    pass == 0 ? 0.0f : 0.5f, // x
                    0.0f,                    // y
                    0.5f,                    // width
                    1.0f                     // height
                };
                //render_params.viewportRect = holokit_api_->GetViewportRect(pass);
                
#else
                // TODO: fill this
#endif
            }
        } else {
            // single-pass rendering
            // TODO: fill this
        }
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    */
    
    UnityXRPose GetPose(int pass)
    {
        UnityXRPose pose{};
        if (pass < (sizeof(s_PoseXPositionPerPass) / sizeof(s_PoseXPositionPerPass[0])))
            pose.position.x = s_PoseXPositionPerPass[pass];
        pose.position.z = -10.0f;
        pose.rotation.w = 1.0f;
        
        pose.rotation.x = 0.0f;
        pose.rotation.y = 0.0f;
        pose.rotation.z = 0.0f;
        return pose;
    }
    
    UnityXRProjection GetProjection(int pass)
    {
        UnityXRProjection ret;
        ret.type = kUnityXRProjectionTypeHalfAngles;
        ret.data.halfAngles.left = -1.0;
        ret.data.halfAngles.right = 1.0;
        ret.data.halfAngles.top = 0.625;
        ret.data.halfAngles.bottom = -0.625;
        return ret;
    }
    
    // TODO: delete this
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame)
    {
        
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()", GetCurrentTime());
        WORKAROUND_SKIP_FIRST_FRAME();

        // BlockUntilUnityShouldStartSubmittingRenderingCommands();

        
        bool reallocateTextures = (unity_textures_.size() == 0);
        if ((kUnityXRFrameSetupHintsChangedSinglePassRendering & frame_hints->changedFlags) != 0)
        {
            reallocateTextures = true;
        }
        if ((kUnityXRFrameSetupHintsChangedRenderViewport & frame_hints->changedFlags) != 0)
        {
            // Change sampling UVs for compositor, pass through new viewport on `nextFrame`
        }
        if ((kUnityXRFrameSetupHintsChangedTextureResolutionScale & frame_hints->changedFlags) != 0)
        {
            reallocateTextures = true;
        }
        if ((kUnityXRFrameSetuphintsChangedContentProtectionState & frame_hints->changedFlags) != 0)
        {
            // App wants different content protection mode.
        }
        if ((kUnityXRFrameSetuphintsChangedReprojectionMode & frame_hints->changedFlags) != 0)
        {
            // App wants different reprojection mode, configure compositor if possible.
        }
        if ((kUnityXRFrameSetuphintsChangedFocusPlane & frame_hints->changedFlags) != 0)
        {
            // App changed focus plane, configure compositor if possible.
        }

        if (reallocateTextures)
        {
            textures_initialized_ = false;
            native_textures_got_ = false;
            DestroyTextures();

    #if SIDE_BY_SIDE
            int numTextures = 1;
            int textureArrayLength = 0;
    #else
            int numTextures = frameHints.appSetup.singlePassRendering ? NUM_RENDER_PASSES - 1 : NUM_RENDER_PASSES;
            int textureArrayLength = frameHints.appSetup.singlePassRendering ? 2 : 0;
    #endif
            CreateTextures(numTextures, textureArrayLength, frame_hints->appSetup.textureResolutionScale);
        }

        // Frame hints tells us if we should setup our renderpasses with a single pass
        if (!frame_hints->appSetup.singlePassRendering)
        {

            // Can increase render pass count to do wide FOV or to have a separate view into scene.
            next_frame->renderPassesCount = NUM_RENDER_PASSES;

            for (int pass = 0; pass < next_frame->renderPassesCount; ++pass)
            {
                auto& renderPass = next_frame->renderPasses[pass];

                // Texture that unity will render to next frame.  We created it above.
                // You might want to change this dynamically to double / triple buffer.
    #if !SIDE_BY_SIDE
                renderPass.textureId = unity_textures_[pass];
    #else
                renderPass.textureId = unity_textures_[0];
    #endif

                // One set of render params per pass.
                renderPass.renderParamsCount = 1;

                // Note that you can share culling between multiple passes by setting this to the same index.
                renderPass.cullingPassIndex = pass;

                // Fill out render params. View, projection, viewport for pass.
                auto& cullingPass = next_frame->cullingPasses[pass];
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
            
        }
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_Stop() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_Stop()", GetCurrentTime());
        // TODO: reset holokit api
        
        is_initialized_ = false;
        return kUnitySubsystemErrorCodeSuccess;
    }

#pragma mark - Private Methods
private:
    
    /// @brief Allocate unity textures.
    void CreateTextures(int num_textures, int texture_array_length, float requested_texture_scale) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f CreateTextures()", GetCurrentTime());
        
        // initialize or reset holokit_api_
        holokit_api_.reset(new holokit::HoloKitApi);
        holokit_api_->Initialize();
        NSLog(@"holokit_api_ initialization succeeded!!@!!!!");
        is_initialized_ = true;
        
        // TODO: improve this
        const int tex_width = 2778;//(int)(2778.0f * requested_texture_scale);
        const int tex_height = 1284;//(int)(1284.0f * requested_texture_scale);
        
        native_textures_.resize(num_textures);
        unity_textures_.resize(num_textures);
#if XR_METAL
        metal_textures_.resize(num_textures);
#endif
        
        for (int i = 0; i < num_textures; i++) {
            UnityXRRenderTextureDesc texture_desc;
            memset(&texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            
            //texture_desc.colorFormat = kUnityXRRenderTextureFormatRGBA32;
            // we will query the pointer of unity created texture later
            texture_desc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            // TODO: do we need depth?
            //texture_desc.depthFormat = kUnityXRDepthTextureFormat24bitOrGreater;
            //texture_desc.depth.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            texture_desc.width = tex_width;
            texture_desc.height = tex_height;
            texture_desc.textureArrayLength = texture_array_length;
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_desc, &unity_texture_id);
            unity_textures_[i] = unity_texture_id;
        }
        textures_initialized_ = true;
    }
    
    /*
    void CreateTextures(int numTextures, int textureArrayLength, float requestedTextureScale)
    {
        //XR_TRACE_LOG(m_Ctx.trace, "<<<<<<<<<< %f CreateTextures()\n", getCurrentTime());
        
        const int texWidth = 2778; //(int)(1920.0f * requestedTextureScale * (SIDE_BY_SIDE ? 2.0f : 1.0f));
        const int texHeight = 1284; //(int)(1200.0f * requestedTextureScale);
        //const int texWidth = (int)(1920.0f * requestedTextureScale * (SIDE_BY_SIDE ? 2.0f : 1.0f));
        //const int texHeight = (int)(1200.0f * requestedTextureScale);
        
        native_textures_.resize(numTextures);
        unity_textures_.resize(numTextures);
        metal_textures_.resize(numTextures);

        // Tell unity about the native textures, getting back UnityXRRenderTextureIds.
        for (int i = 0; i < numTextures; ++i)
        {
            UnityXRRenderTextureDesc uDesc;
            memset(&uDesc, 0 , sizeof(UnityXRRenderTextureDesc));
            
            uDesc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            uDesc.depth.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            uDesc.depthFormat = kUnityXRDepthTextureFormat24bitOrGreater;
            //NSLog(@"@", uDesc.color.nativePtr);
            //NSLog(@"--------------------------------------");
                
            uDesc.width = texWidth;
            uDesc.height = texHeight;
            uDesc.textureArrayLength = textureArrayLength;

            // Create an UnityXRRenderTextureId for the native texture so we can tell unity to render to it later.
            UnityXRRenderTextureId uTexId;
            display_->CreateTexture(handle_, &uDesc, &uTexId);
            unity_textures_[i] = uTexId;
        }
        textures_initialized_ = true;
    }
    */
    //TODO: delete this
    
    /// @brief Deallocate textures.
    void DestroyTextures() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f DestroyTextures()", GetCurrentTime());
        
        assert(native_textures_.size() == unity_textures_.size());
        
        for (int i = 0; i < unity_textures_.size(); i++) {
            if(unity_textures_[i] != 0) {
                display_->DestroyTexture(handle_, unity_textures_[i]);
                native_textures_[i] = nullptr;
#if XR_METAL
                // TODO: release metal texture
#endif
            }
        }
        
        unity_textures_.clear();
        native_textures_.clear();
#if XR_METAL
        metal_textures_.clear();
#endif
    }
    
#pragma mark - Private Properties
private:
    ///@brief Points to Unity XR Trace interface.
    IUnityXRTrace* trace_ = nullptr;
    
    ///@brief Points to Unity XR Display interface.
    IUnityXRDisplayInterface* display_ = nullptr;
    
    ///@brief Opaque Unity pointer type passed between plugins.
    UnitySubsystemHandle handle_;
    
    ///@brief Tracks HoloKit API initialization status.
    bool is_initialized_ = false;
    
    ///@brief Screen width in pixels.
    int width_;
    
    ///@brief Screen height in pixels.
    int height_;
    
    /// @brief HoloKit SDK API wrapper.
    std::unique_ptr<holokit::HoloKitApi> holokit_api_;
    
    /// @brief An array of native texture pointers.
    std::vector<void*> native_textures_;
    
    /// @brief An array of UnityXRRenderTextureId.
    std::vector<UnityXRRenderTextureId> unity_textures_;
    
    bool textures_initialized_ = false;
    
    bool native_textures_got_ = false;
    
    bool metal_initialized_ = false;
    
    id<MTLDevice> mtl_device_;
    
    NSBundle* mtl_bundle_;
    
#if XR_METAL
    /// @brief Points to Metal interface.
    IUnityGraphicsMetal* metal_interface_;
    
    /// @brief An array of metal textures.
    std::vector<id<MTLTexture>> metal_textures_;
#elif XR_ANDROID
    // TODO: fill in
#endif
    
    static std::unique_ptr<HoloKitDisplayProvider> display_provider_;
};

std::unique_ptr<HoloKitDisplayProvider> HoloKitDisplayProvider::display_provider_;

std::unique_ptr<HoloKitDisplayProvider>& HoloKitDisplayProvider::GetInstance() {
    return display_provider_;
}

} // namespace

UnitySubsystemErrorCode LoadDisplay(IUnityInterfaces* xr_interfaces) {
    auto* display = xr_interfaces->Get<IUnityXRDisplayInterface>();
    if(display == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    auto* trace = xr_interfaces->Get<IUnityXRTrace>();
    if(trace == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    HoloKitDisplayProvider::GetInstance().reset(new HoloKitDisplayProvider(trace, display));
    HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, "%f LoadDisplay()", GetCurrentTime());
    
    HoloKitDisplayProvider::GetInstance()->SetMtlInterface(xr_interfaces->Get<IUnityGraphicsMetal>());
    HoloKitDisplayProvider::GetInstance()->SetMtlDevice(xr_interfaces->Get<IUnityGraphicsMetal>()->MetalDevice());
    HoloKitDisplayProvider::GetInstance()->SetNSBundle(xr_interfaces->Get<IUnityGraphicsMetal>()->MetalBundle());
    
    UnityLifecycleProvider display_lifecycle_handler;
    display_lifecycle_handler.userData = NULL;
    display_lifecycle_handler.Initialize = [](UnitySubsystemHandle handle, void*) -> UnitySubsystemErrorCode {
        return HoloKitDisplayProvider::GetInstance()->Initialize(handle);
    };
    display_lifecycle_handler.Start = [](UnitySubsystemHandle, void*) -> UnitySubsystemErrorCode {
        return HoloKitDisplayProvider::GetInstance()->Start();
    };
    display_lifecycle_handler.Stop = [](UnitySubsystemHandle, void*) -> void {
        return HoloKitDisplayProvider::GetInstance()->Stop();
    };
    display_lifecycle_handler.Shutdown = [](UnitySubsystemHandle, void*) -> void {
        return HoloKitDisplayProvider::GetInstance()->Shutdown();
    };
    
    // the names do matter
    // The parameters passed to RegisterLifecycleProvider must match the name and id fields in your manifest file.
    // see https://docs.unity3d.com/Manual/xrsdk-provider-setup.html
    return HoloKitDisplayProvider::GetInstance()->GetDisplay()->RegisterLifecycleProvider("HoloKit XR Plugin", "HoloKit Display", &display_lifecycle_handler);
}

void UnloadDisplay() { HoloKitDisplayProvider::GetInstance().reset(); }
