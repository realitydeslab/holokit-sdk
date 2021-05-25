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
#include <MetalKit/MetalKit.h>
#import <simd/simd.h>
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

// widgets data
float vertex_data[] = {
    0.829760, 1, 0.0, 1.0,
    0.829760, 0.7, 0.0, 1.0
};

NSString* kBlackShaders = @
    R"msl(
    #include <metal_stdlib>
    using namespace metal;

    struct VertexInput {
        float2 in_position [[attribute(0)]];
    };

    struct VertexOutput {
        float4 out_position [[position]];
    };

    struct FragmentOutput {
        half4 color [[color(0)]];
    };

    vertex VertexOutput vertex_main(VertexInput input [[stage_in]]) {
        VertexOutput out = { float4(input.in_position, 0, 1) };
        return out;
    }

    fragment FragmentOutput fragment_main(VertexOutput input [[stage_in]]) {
        FragmentOutput out = { half4(0, 1, 0, 1) };
        return out;
    }
    )msl";

const float black_vertices[] = {
    -1.0f, 1.0f,
    -1.0f, -1.0f,
    1.0f, -1.0f,
    1.0f, 1.0f
};

const uint16_t black_indexes[] = {0, 1, 2, 2, 3, 0};

simd_float4x4 unity_projection_matrix;

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
        
        if(textures_initialized_ == NO) {
            return kUnitySubsystemErrorCodeSuccess;
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
            
            MTLVertexBufferLayoutDescriptor* buffer_layout_descriptor = [[MTLVertexBufferLayoutDescriptor alloc] init];
            buffer_layout_descriptor.stride = 4 * sizeof(float);
            buffer_layout_descriptor.stepFunction = MTLVertexStepFunctionPerVertex;
            buffer_layout_descriptor.stepRate = 1;
            
            MTLVertexAttributeDescriptor* attribute_descriptor = [[MTLVertexAttributeDescriptor alloc] init];
            attribute_descriptor.format = MTLVertexFormatFloat4;
            
            MTLVertexDescriptor* vertex_descriptor = [[MTLVertexDescriptor alloc] init];
            vertex_descriptor.attributes[0] = attribute_descriptor;
            vertex_descriptor.layouts[0] = buffer_layout_descriptor;
            
            MTLRenderPipelineDescriptor* render_pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];

            render_pipeline_descriptor.fragmentFunction = fragment_function;
            render_pipeline_descriptor.vertexFunction = vertex_function;
            render_pipeline_descriptor.vertexDescriptor = vertex_descriptor;
            render_pipeline_descriptor.sampleCount = 1;
            render_pipeline_descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            render_pipeline_descriptor.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            render_pipeline_descriptor.colorAttachments[0].blendingEnabled = YES;
            render_pipeline_descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            render_pipeline_descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            render_pipeline_descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            //render_pipeline_descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero; // MTLBlendFactorSourceAlpha;
            // TODO: this pamameter is vital.
            //render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
            //render_pipeline_descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorZero;// MTLBlendFactorOneMinusSourceAlpha;
            
            render_pipeline_state_ = [mtl_device_ newRenderPipelineStateWithDescriptor:render_pipeline_descriptor error:nil];
            is_metal_initialized_ = true;
        }
        
        // Draw a black screen beforehand to eliminate left viewport glitch
        // This does not work...
        //RenderBlackScreen();
        
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
            
            widgets_vertex_buffer_ = [mtl_device_ newBufferWithBytes:vertex_data length:sizeof(vertex_data) options:MTLResourceOptionCPUCacheModeDefault];
            widgets_vertex_buffer_.label = @"vertices";
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
        [command_encoder setVertexBuffer:widgets_vertex_buffer_ offset:0 atIndex:0];
        //[command_encoder setVertexBuffer:vertex_color_buffer offset:0 atIndex:1];
        [command_encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:(sizeof(vertex_data) / sizeof(float))];
        //NSLog(@"draw call");
    }
    
    void RenderBlackScreen() {
        if (!is_black_screen_renderer_setup_) {
            // Pass vertex buffer data to the GPU
            black_vertex_buffer_ = [mtl_device_ newBufferWithBytes:black_vertices length:sizeof(black_vertices) options:MTLResourceOptionCPUCacheModeDefault];
            black_index_buffer_ = [mtl_device_ newBufferWithBytes:black_indexes length:sizeof(black_indexes) options:MTLResourceOptionCPUCacheModeDefault];
            
            id<MTLLibrary> mtl_library = [mtl_device_ newLibraryWithSource:kBlackShaders options:nil error:nil];
            
            if (mtl_library == nil) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Failed to compile Metal library.");
                return;
            }
            
            id<MTLFunction> vertex_function = [mtl_library newFunctionWithName:@"vertex_main"];
            id<MTLFunction> fragment_function = [mtl_library newFunctionWithName:@"fragment_main"];
            
            // Setup vertex descriptor
            MTLVertexBufferLayoutDescriptor* buffer_layout_descriptor = [[MTLVertexBufferLayoutDescriptor alloc] init];
            buffer_layout_descriptor.stride = 2 * sizeof(float);
            buffer_layout_descriptor.stepFunction = MTLVertexStepFunctionPerVertex;
            buffer_layout_descriptor.stepRate = 1;
            
            MTLVertexAttributeDescriptor* attribute_descriptor = [[MTLVertexAttributeDescriptor alloc] init];
            attribute_descriptor.format = MTLVertexFormatFloat2;
            
            MTLVertexDescriptor* vertex_descriptor = [[MTLVertexDescriptor alloc] init];
            vertex_descriptor.layouts[0] = buffer_layout_descriptor;
            vertex_descriptor.attributes[0] = attribute_descriptor;
            
            // Create pipeline
            MTLRenderPipelineDescriptor* mtl_render_pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
            mtl_render_pipeline_descriptor.vertexFunction = vertex_function;
            mtl_render_pipeline_descriptor.fragmentFunction = fragment_function;
            mtl_render_pipeline_descriptor.vertexDescriptor = vertex_descriptor;
            mtl_render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            mtl_render_pipeline_descriptor.sampleCount = 1;
            
            black_render_pipeline_state_ = [mtl_device_ newRenderPipelineStateWithDescriptor:mtl_render_pipeline_descriptor error:nil];
            if (black_render_pipeline_state_ == nil) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Failed to create Metal render pipeline.");
                return;
            }
            is_black_screen_renderer_setup_ = true;
        }
        
        // Rendering commands that are executed for each frame.
        id<MTLRenderCommandEncoder> mtl_render_command_encoder = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [mtl_render_command_encoder setRenderPipelineState:black_render_pipeline_state_];
        [mtl_render_command_encoder setCullMode:MTLCullModeNone];
        [mtl_render_command_encoder setVertexBuffer:black_vertex_buffer_ offset:0 atIndex:0];
        [mtl_render_command_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:black_index_buffer_ indexBufferOffset:0];
        NSLog(@"Draw black screen");
    }

#pragma mark - PopulateNextFrame()
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {
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
            projection_matrix = unity_projection_matrix;
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
//            render_params.viewportRect = {
//                0.0f,                    // x
//                0.0f,                    // y
//                0.5f,                    // width
//                0.5f                     // height
//            };
            return kUnitySubsystemErrorCodeSuccess;
        }
        
        // CHANGE THIS TO SWITCH BETWEEN RENDERING MODES
        bool single_pass_rendering = true;
        // Frame hints tells us if we should setup our renderpasses with a single pass
        if (!single_pass_rendering)
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
            // Single-pass rendering
            next_frame->renderPassesCount = 1;
            auto& render_pass = next_frame->renderPasses[0];
            render_pass.textureId = unity_textures_[0];
            
            render_pass.renderParamsCount = 2;
            // TODO: what is this?
            render_pass.cullingPassIndex = 0;
            for (int i = 0; i < 2; i++) {
                auto& culling_pass = next_frame->cullingPasses[i];
                // TODO: what is this?
                culling_pass.separation = fabs(s_PoseXPositionPerPass[1]) + fabs(s_PoseXPositionPerPass[0]);
                
                auto& render_params = render_pass.renderParams[i];
                render_params.deviceAnchorToEyePose = culling_pass.deviceAnchorToCullingPose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(i));
                render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(i));
                render_params.viewportRect = Float4ToUnityXRRect(holokit::HoloKitApi::GetInstance()->GetViewportRect(i));
            }
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
        
        // TODO: improve this
        const int screen_width = holokit::HoloKitApi::GetInstance()->GetScreenWidth() * requested_texture_scale;
        const int screen_height = holokit::HoloKitApi::GetInstance()->GetScreenHeight() * requested_texture_scale;
        
        unity_textures_.resize(num_textures);
        native_color_textures_.resize(num_textures);
        native_depth_textures_.resize(num_textures);
#if XR_METAL
        color_surfaces_.resize(num_textures);
        metal_color_textures_.resize(num_textures);
        metal_depth_textures_.resize(num_textures);
#endif
        
        for (int i = 0; i < num_textures; i++) {
            UnityXRRenderTextureDesc texture_descriptor;
            memset(&texture_descriptor, 0, sizeof(UnityXRRenderTextureDesc));
            
            texture_descriptor.width = screen_width;
            texture_descriptor.height = screen_height;
            texture_descriptor.flags = 0;
            texture_descriptor.depthFormat = kUnityXRDepthTextureFormatNone;
            
            // Create texture color buffer.
            NSDictionary* color_surface_attribs = @{
                (NSString*)kIOSurfaceIsGlobal : @ YES,
                (NSString*)kIOSurfaceWidth : @(screen_width),
                (NSString*)kIOSurfaceHeight : @(screen_height),
                (NSString*)kIOSurfaceBytesPerElement : @4u
            };
            color_surfaces_[i] = IOSurfaceCreate((CFDictionaryRef)color_surface_attribs);
            MTLTextureDescriptor* texture_color_buffer_descriptor = [[MTLTextureDescriptor alloc] init];
            texture_color_buffer_descriptor.textureType = MTLTextureType2D;
            texture_color_buffer_descriptor.width = screen_width;
            texture_color_buffer_descriptor.height = screen_height;
            texture_color_buffer_descriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
            texture_color_buffer_descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
            metal_color_textures_[i] = [mtl_device_ newTextureWithDescriptor:texture_color_buffer_descriptor iosurface:color_surfaces_[i] plane:0];
            uint64_t color_buffer = reinterpret_cast<uint64_t>(color_surfaces_[i]);
            native_color_textures_[i] = reinterpret_cast<void*>(color_buffer);
            uint64_t depth_buffer = 0;
            native_depth_textures_[i] = reinterpret_cast<void*>(depth_buffer);
            
            texture_descriptor.color.nativePtr = native_color_textures_[i];
            texture_descriptor.depth.nativePtr = native_depth_textures_[i];
            
            texture_descriptor.textureArrayLength = texture_array_length;
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_descriptor, &unity_texture_id);
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
    
    /// @brief An array of UnityXRRenderTextureId.
    std::vector<UnityXRRenderTextureId> unity_textures_;
    
    /// @brief An array of native texture pointers.
    std::vector<void*> native_color_textures_;
    
    std::vector<void*> native_depth_textures_;
    
    std::vector<IOSurfaceRef> color_surfaces_;
    
    /// @brief An array of metal textures.
    std::vector<id<MTLTexture>> metal_color_textures_;
    
    std::vector<id<MTLTexture>> metal_depth_textures_;
    
    bool textures_initialized_ = false;
    
    /// @brief This value is set to true when Metal is initialized for the first time.
    bool is_metal_initialized_ = false;
    
    bool is_black_screen_renderer_setup_ = false;
    
    id <MTLDevice> mtl_device_;
    
    id <MTLRenderPipelineState> render_pipeline_state_;
    
    /// @brief This value is used for rendering widgets.
    bool is_metal_initialized_widgets_ = false;
    
    id <MTLBuffer> vertex_buffer_;
    id <MTLBuffer> index_buffer_;
    
    id <MTLBuffer> widgets_vertex_buffer_;
    
    id <MTLBuffer> black_vertex_buffer_;
    id <MTLBuffer> black_index_buffer_;
    
    id <MTLRenderPipelineState> render_pipeline_state_widgets_;
    
    id <MTLRenderPipelineState> black_render_pipeline_state_;
    
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

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetUnityProjectionMatrix(float column0[4], float column1[4], float column2[4], float column3[4]) {
    unity_projection_matrix.columns[0].x = column0[0];
    unity_projection_matrix.columns[0].y = column0[1];
    unity_projection_matrix.columns[0].z = column0[2];
    unity_projection_matrix.columns[0].w = column0[3];
    
    unity_projection_matrix.columns[1].x = column1[0];
    unity_projection_matrix.columns[1].y = column1[1];
    unity_projection_matrix.columns[1].z = column1[2];
    unity_projection_matrix.columns[1].w = column1[3];
    
    unity_projection_matrix.columns[2].x = column2[0];
    unity_projection_matrix.columns[2].y = column2[1];
    unity_projection_matrix.columns[2].z = column2[2];
    unity_projection_matrix.columns[2].w = column2[3];
    
    unity_projection_matrix.columns[3].x = column3[0];
    unity_projection_matrix.columns[3].y = column3[1];
    unity_projection_matrix.columns[3].z = column3[2];
    unity_projection_matrix.columns[3].w = column3[3];
}
