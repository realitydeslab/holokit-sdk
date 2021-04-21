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
#include "holokit_api.h"

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
NSString* side_by_side_shader = @
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

// position + texture coordinate
const float vdata[] = {
        -1.0f,  1.0f, 0.0f, 0.0f,
        -1.0f, -1.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 1.0f, 1.0f,
        1.0f,  1.0f, 1.0f, 0.0f,
    };

const uint16_t idata[] = {0, 1, 2, 2, 3, 0};

// widgets data
float vertex_data[] = {
    0.829760, 1, 0.0, 1.0,
    0.829760, 0.7, 0.0, 1.0
};

NSString* myShader = @
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct VertexInOut\n"
"{\n"
"    float4  position [[position]];\n"
"    float4  color;\n"
"};\n"
"vertex VertexInOut passThroughVertex(uint vid [[ vertex_id ]],\n"
"                                     constant packed_float4* position  [[ buffer(0) ]])\n"
"{\n"
"    VertexInOut outVertex;\n"
"    outVertex.position = position[vid];\n"
"    return outVertex;\n"
"};\n"
"fragment half4 passThroughFragment(VertexInOut inFrag [[stage_in]])\n"
"{\n"
"//  return half4(1, 0, 0, 1);\n"
"    return half4(1, 1, 1, 1);\n"
"};\n";

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

#pragma mark - Display Lifecycle Methods
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
    
    UnitySubsystemErrorCode Start() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Start()", GetCurrentTime());
        
        is_xr_mode_enabled_ = true;
        display_mode_changed_ = false;
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop() const {}
    
    void Shutdown() const {}
    
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
    

#pragma mark - SubmitCurrentFrame()
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_SubmitCurrentFrame()", GetCurrentTime());
        
        // delete this
        //id<MTLTexture> texture = metal_interface_->CurrentRenderPassDescriptor().depthAttachment.texture;
        //NSLog(@"depth format %d", texture.pixelFormat);
        //  MTLPixelFormatDepth32Float_Stencil8
        
        if(textures_initialized_ == NO) {
            return kUnitySubsystemErrorCodeSuccess;
        }
        if(native_textures_queried_ == NO) {
            // Query left eye texture
            UnityXRRenderTextureDesc unity_texture_desc;
            memset(&unity_texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            UnitySubsystemErrorCode query_result = display_->QueryTextureDesc(handle_, unity_textures_[0], &unity_texture_desc);
            if (query_result == kUnitySubsystemErrorCodeSuccess) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query succeeded()", GetCurrentTime());
            } else {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query failed()", GetCurrentTime());
            }
            native_color_textures_[0] = unity_texture_desc.color.nativePtr;
            native_depth_textures_[0] = unity_texture_desc.depth.nativePtr;
            metal_color_textures_[0] = (__bridge id<MTLTexture>)native_color_textures_[0];
            metal_depth_textures_[0] = (__bridge id<MTLTexture>)native_depth_textures_[0];
            // TODO: query the right eye texture when SIDE_BY_SIDE = 0
    #if !SIDE_BY_SIDE
            query_result = display_->QueryTextureDesc(handle_, unity_textures_[1], &unity_texture_desc);
            if (query_result == kUnitySubsystemErrorCodeSuccess) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query succeeded()", GetCurrentTime());
            } else {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Texture query failed()", GetCurrentTime());
            }
            native_color_textures_[1] = unity_texture_desc.color.nativePtr;
            native_depth_textures_[1] = unity_texture_desc.depth.nativePtr;
            metal_color_textures_[1] = (__bridge id<MTLTexture>)native_color_textures_[1];
            metal_depth_textures_[1] = (__bridge id<MTLTexture>)native_depth_textures_[1];
    #endif
            native_textures_queried_ = true;
        }
        
        // Metal initialization is expensive and we only want to run it once.
        if (!is_metal_initialized_) {
            // set up buffers
            vertex_buffer_ = [mtl_device_ newBufferWithBytes:vdata length:sizeof(vdata) options:MTLResourceOptionCPUCacheModeDefault];
            index_buffer_ = [mtl_device_ newBufferWithBytes:idata length:sizeof(idata) options:MTLResourceOptionCPUCacheModeDefault];
            // Set up library and functions
            id<MTLLibrary> lib = [mtl_device_ newLibraryWithSource:side_by_side_shader options:nil error:nil];
            //id<MTLLibrary> lib = [mtlDevice newDefaultLibrary];
            id<MTLFunction> vertex_function = [lib newFunctionWithName:@"vprog"];
            id<MTLFunction> fragment_function = [lib newFunctionWithName:@"fshader_tex"];
            mtl_bundle_ = metal_interface_->MetalBundle();
            
            MTLVertexBufferLayoutDescriptor* buffer_layout_descriptor = [[mtl_bundle_ classNamed:@"MTLVertexBufferLayoutDescriptor"] new];
            buffer_layout_descriptor.stride = 4 * sizeof(float);
            buffer_layout_descriptor.stepFunction = MTLVertexStepFunctionPerVertex;
            buffer_layout_descriptor.stepRate = 1;
            
            MTLVertexAttributeDescriptor* attribute_descriptor = [[mtl_bundle_ classNamed:@"MTLVertexAttributeDescriptor"] new];
            attribute_descriptor.format = MTLVertexFormatFloat4;
            
            MTLVertexDescriptor* vertex_descriptor = [[mtl_bundle_ classNamed:@"MTLVertexDescriptor"] vertexDescriptor];
            vertex_descriptor.attributes[0] = attribute_descriptor;
            vertex_descriptor.layouts[0] = buffer_layout_descriptor;
            
            MTLRenderPipelineDescriptor* render_pipeline_descriptor = [[mtl_bundle_ classNamed:@"MTLRenderPipelineDescriptor"] new];

            MTLRenderPipelineColorAttachmentDescriptor* color_attachment_descriptor = [[mtl_bundle_ classNamed:@"MTLRenderPipelineColorAttachmentDescriptor"] new];
            color_attachment_descriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
            render_pipeline_descriptor.colorAttachments[0] = color_attachment_descriptor;

            //pipeDesc.fragmentFunction = g_FShaderColor;
            render_pipeline_descriptor.fragmentFunction = fragment_function;
            render_pipeline_descriptor.vertexFunction = vertex_function;
            render_pipeline_descriptor.vertexDescriptor = vertex_descriptor;
            render_pipeline_descriptor.sampleCount = 1;
            render_pipeline_state_ = [mtl_device_ newRenderPipelineStateWithDescriptor:render_pipeline_descriptor error:nil];
            is_metal_initialized_ = true;
        }
        
        id<MTLRenderCommandEncoder> render_command_encoder = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [render_command_encoder setRenderPipelineState:render_pipeline_state_];
        [render_command_encoder setCullMode:MTLCullModeNone];
        [render_command_encoder setVertexBuffer:vertex_buffer_ offset:0 atIndex:0];
        [render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:0];
#if SIDE_BY_SIDE
        [render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:1];
#else
        [render_command_encoder setFragmentTexture:metal_color_textures_[1] atIndex:1];
#endif
        [render_command_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:index_buffer_ indexBufferOffset:0];
        
        RenderWidgets();
        //NSLog(@"horizontal alignment offset: %f", holokit::HoloKitApi::GetInstance()->GetHorizontalAlignmentMarkerOffset());
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void RenderWidgets() {
        if (!is_metal_initialized_widgets_) {
            vertex_data[0] = vertex_data[4] = holokit::HoloKitApi::GetInstance()->GetHorizontalAlignmentMarkerOffset();
            
            vertex_buffer_widgets_ = [mtl_device_ newBufferWithBytes:vertex_data length:sizeof(vertex_data) options:MTLResourceOptionCPUCacheModeDefault];
            vertex_buffer_widgets_.label = @"vertices";
            //id<MTLBuffer> vertex_color_buffer = [mtl_device_ newBufferWithBytes:vertex_color_data length:sizeof(vertex_color_data) options:MTLResourceOptionCPUCacheModeDefault];
            //vertex_color_buffer.label = @"colors";
            
            id<MTLLibrary> lib = [mtl_device_ newLibraryWithSource:myShader options:nil error:nil];
            id<MTLFunction> vertex_function = [lib newFunctionWithName:@"passThroughVertex"];
            id<MTLFunction> fragment_function = [lib newFunctionWithName:@"passThroughFragment"];
            
            MTLRenderPipelineDescriptor* pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipeline_descriptor.vertexFunction = vertex_function;
            pipeline_descriptor.fragmentFunction = fragment_function;
            pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            pipeline_descriptor.sampleCount = 1;
            
            render_pipeline_state_widgets_ = [mtl_device_ newRenderPipelineStateWithDescriptor:pipeline_descriptor error:nil];
            is_metal_initialized_widgets_ = true;
        }
        
        id<MTLRenderCommandEncoder> command_encoder = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [command_encoder setRenderPipelineState:render_pipeline_state_widgets_];
        [command_encoder setVertexBuffer:vertex_buffer_widgets_ offset:0 atIndex:0];
        //[command_encoder setVertexBuffer:vertex_color_buffer offset:0 atIndex:1];
        [command_encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:(sizeof(vertex_data) / sizeof(float))];
        //NSLog(@"draw call");
    }

#pragma mark - PopulateNextFrame()
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame)
    {
        
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()", GetCurrentTime());
        WORKAROUND_SKIP_FIRST_FRAME();

        // BlockUntilUnityShouldStartSubmittingRenderingCommands();
        
        
        // Check if holokit api has changed the display mode.
        if (is_xr_mode_enabled_ != holokit::HoloKitApi::GetInstance()->GetIsXrModeEnabled()) {
            HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Display mode switched.", GetCurrentTime());
            NSLog(@"%d", holokit::HoloKitApi::GetInstance()->GetIsXrModeEnabled());
            is_xr_mode_enabled_ = holokit::HoloKitApi::GetInstance()->GetIsXrModeEnabled();
            display_mode_changed_ = true;
        }

        
        bool reallocate_textures = (unity_textures_.size() == 0);
        if ((kUnityXRFrameSetupHintsChangedSinglePassRendering & frame_hints->changedFlags) != 0)
        {
            reallocate_textures = true;
        }
        if ((kUnityXRFrameSetupHintsChangedRenderViewport & frame_hints->changedFlags) != 0)
        {
            // Change sampling UVs for compositor, pass through new viewport on `nextFrame`
        }
        if ((kUnityXRFrameSetupHintsChangedTextureResolutionScale & frame_hints->changedFlags) != 0)
        {
            reallocate_textures = true;
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
        if (display_mode_changed_) {
            reallocate_textures = true;
            display_mode_changed_ = false;
        }

        if (reallocate_textures) {
            textures_initialized_ = false;
            native_textures_queried_ = false;
            DestroyTextures();

    #if SIDE_BY_SIDE
            int num_textures = 1;
            int texture_array_length = 0;
    #else
            int num_textures = 2;
            int texture_array_length = frame_hints->appSetup.singlePassRendering ? 2 : 0;
    #endif
            if (!is_xr_mode_enabled_) {
                num_textures = 1;
                texture_array_length = 0;
            }
            
            CreateTextures(num_textures, texture_array_length, frame_hints->appSetup.textureResolutionScale);
        }
        
        // AR mode rendering
        if (!is_xr_mode_enabled_) {
            next_frame->renderPassesCount = 1;
            
            auto& render_pass = next_frame->renderPasses[0];
            render_pass.textureId = unity_textures_[0];
            render_pass.renderParamsCount = 1;
            render_pass.cullingPassIndex = 0;
            
            auto& culling_pass = next_frame->cullingPasses[0];
            // TODO: culling pass separation
            //culling_pass.separation = fabs(s_PoseXPositionPerPass[1]) + fabs(s_PoseXPositionPerPass[0]);
            
            auto& render_params = render_pass.renderParams[0];
            // view matrix
            UnityXRVector3 position = UnityXRVector3 { 0, 0, 0 };
            UnityXRVector4 rotation = UnityXRVector4 { 0, 0, 0, 1 };
            UnityXRPose pose = { position, rotation };
            render_params.deviceAnchorToEyePose = culling_pass.deviceAnchorToCullingPose = pose;
            // projection matrix
            // get ARKit projection matrix
            simd_float4x4 projection_matrix = holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session.currentFrame.camera.projectionMatrix;
            //LogMatrix4x4(projection_matrix);
            render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
            // Make sure we can see the splash screen when ar session is not initialized.
            if (holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session == NULL) {
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(0));
            } else {
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = Float4x4ToUnityXRMatrix(projection_matrix);
            }
            // viewport
            render_params.viewportRect = frame_hints->appSetup.renderViewport;
            return kUnitySubsystemErrorCodeSuccess;
        }

        // Frame hints tells us if we should setup our renderpasses with a single pass
        if (!frame_hints->appSetup.singlePassRendering)
        {

            // Can increase render pass count to do wide FOV or to have a separate view into scene.
            next_frame->renderPassesCount = NUM_RENDER_PASSES;

            for (int pass = 0; pass < next_frame->renderPassesCount; ++pass)
            {
                auto& render_pass = next_frame->renderPasses[pass];

                // Texture that unity will render to next frame.  We created it above.
                // You might want to change this dynamically to double / triple buffer.
    #if !SIDE_BY_SIDE
                render_pass.textureId = unity_textures_[pass];
    #else
                render_pass.textureId = unity_textures_[0];
    #endif

                // One set of render params per pass.
                render_pass.renderParamsCount = 1;

                // Note that you can share culling between multiple passes by setting this to the same index.
                render_pass.cullingPassIndex = pass;

                // Fill out render params. View, projection, viewport for pass.
                auto& culling_pass = next_frame->cullingPasses[pass];
                culling_pass.separation = fabs(s_PoseXPositionPerPass[1]) + fabs(s_PoseXPositionPerPass[0]);

                auto& render_params = render_pass.renderParams[0];
                render_params.deviceAnchorToEyePose = culling_pass.deviceAnchorToCullingPose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(pass));
                render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
                render_params.projection.data.matrix = culling_pass.projection.data.matrix =  Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(pass));

    #if !SIDE_BY_SIDE
                // App has hinted that it would like to render to a smaller viewport.  Tell unity to render to that viewport.
                render_params.viewportRect = frame_hints->appSetup.renderViewport;
                // x = 0, y = 0, width = 1, height = 1.
                // Render to the full screen basically.
                //NSLog(@"render pass #%f", pass);
                //NSLog(@"render viewport x: %f, y: %f, width: %f, height: %f", render_params.viewportRect.x, render_params.viewportRect.y, render_params.viewportRect.width, render_params.viewportRect.height);

                // Tell the compositor what pixels were rendered to for display.
                // Compositor_SetRenderSubRect(pass, renderParams.viewportRect);
    #else
                // TODO: frameHints.appSetup.renderViewport
                render_params.viewportRect = Float4ToUnityXRRect(holokit::HoloKitApi::GetInstance()->GetViewportRect(pass));
                //renderParams.viewportRect = {
                //    pass == 0 ? 0.0f : 0.5f, // x
                //    0.0f,                    // y
                //    0.5f,                    // width
                //    1.0f                     // height
                //};
    #endif
            }
        }
        else
        {
            // TODO: single-pass rendering
        }
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_Stop() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_Stop()", GetCurrentTime());
        // TODO: reset holokit api
        
        return kUnitySubsystemErrorCodeSuccess;
    }

    UnitySubsystemErrorCode UpdateDisplayState(UnityXRDisplayState* state) {
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc * blitDescriptor) {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f QueryMirrorViewBlitDesc()", GetCurrentTime());
        return kUnitySubsystemErrorCodeFailure;
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
    
#pragma mark - CreateTextures()
private:
    
    /// @brief Allocate unity textures.
    void CreateTextures(int num_textures, int texture_array_length, float requested_texture_scale) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f CreateTextures()", GetCurrentTime());
        
        // initialize or reset holokit_api_
        //holokit_api_.reset(new holokit::HoloKitApi);
        //holokit_api_->Initialize();
        //NSLog(@"holokit_api_ initialization succeeded!!@!!!!");
        //is_initialized_ = true;
        
        // TODO: improve this
        const int tex_width = 2778;//(int)(2778.0f * requested_texture_scale);
        const int tex_height = 1284;//(int)(1284.0f * requested_texture_scale);
        
        unity_textures_.resize(num_textures);
        native_color_textures_.resize(num_textures);
        native_depth_textures_.resize(num_textures);
#if XR_METAL
        metal_color_textures_.resize(num_textures);
        metal_depth_textures_.resize(num_textures);
#endif
        
        for (int i = 0; i < num_textures; i++) {
            UnityXRRenderTextureDesc texture_desc;
            memset(&texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            
            texture_desc.colorFormat = kUnityXRRenderTextureFormatRGBA32;
            // we will query the pointer of unity created texture later
            texture_desc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            // TODO: do we need depth?
            texture_desc.depthFormat = kUnityXRDepthTextureFormat24bitOrGreater;
            //texture_desc.depthFormat = kUnityXRDepthTextureFormatReference;
            texture_desc.depth.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            texture_desc.width = tex_width;
            texture_desc.height = tex_height;
            texture_desc.textureArrayLength = texture_array_length;
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_desc, &unity_texture_id);
            unity_textures_[i] = unity_texture_id;
        }
        textures_initialized_ = true;
    }
    
    /// @brief Deallocate textures.
    void DestroyTextures() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f DestroyTextures()", GetCurrentTime());
        
        assert(native_color_textures_.size() == unity_textures_.size());
        
        for (int i = 0; i < unity_textures_.size(); i++) {
            if(unity_textures_[i] != 0) {
                display_->DestroyTexture(handle_, unity_textures_[i]);
                native_color_textures_[i] = nullptr;
#if XR_METAL
                // TODO: release metal texture
#endif
            }
        }
        
        unity_textures_.clear();
        native_color_textures_.clear();
#if XR_METAL
        metal_color_textures_.clear();
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
    bool is_holokit_api_initialized_ = false;
    
    ///@brief Screen width in pixels.
    int width_;
    
    ///@brief Screen height in pixels.
    int height_;
    
    /// @brief HoloKit SDK API wrapper.
    std::unique_ptr<holokit::HoloKitApi> holokit_api_;
    
    /// @brief An array of native texture pointers.
    std::vector<void*> native_color_textures_;
    
    /// @brief An array of UnityXRRenderTextureId.
    std::vector<UnityXRRenderTextureId> unity_textures_;
    
    /// @brief An array of metal textures.
    std::vector<id<MTLTexture>> metal_color_textures_;
    
    std::vector<void*> native_depth_textures_;
    
    std::vector<id<MTLTexture>> metal_depth_textures_;
    
    bool textures_initialized_ = false;
    
    bool native_textures_queried_ = false;
    
    /// @brief This value is set to true when Metal is initialized for the first time.
    bool is_metal_initialized_ = false;
    
    id <MTLDevice> mtl_device_;
    
    NSBundle* mtl_bundle_;
    
    id <MTLBuffer> vertex_buffer_;
    
    id <MTLBuffer> index_buffer_;
    
    id <MTLRenderPipelineState> render_pipeline_state_;
    
    /// @brief This value is used for rendering widgets.
    bool is_metal_initialized_widgets_ = false;
    
    id <MTLBuffer> vertex_buffer_widgets_;
    
    id <MTLRenderPipelineState> render_pipeline_state_widgets_;
    
    /// @brief Points to Metal interface.
    IUnityGraphicsMetal* metal_interface_;
    
    /// @brief This value is true if XR mode is enabled, false if AR mode is enabled.
    bool is_xr_mode_enabled_;
    
    /// @brief This value is set to true when the user switched from AR mode to XR model, vice versa.
    bool display_mode_changed_;
    
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
