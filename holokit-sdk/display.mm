//
//  display.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <memory>
#include <vector>

#import <os/log.h>
#import <os/signpost.h>

#include "IUnityXRTrace.h"
#include "IUnityXRDisplay.h"
#include "UnitySubsystemTypes.h"
#include "load.h"
#include "math_helpers.h"
#include "holokit_api.h"
#include "profiling_data.h"
#include "ar_recorder.h"

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

// new content rendering data
constexpr static float main_vertices[] = { -1, -1, 1, -1, -1, 1, 1, 1 };
constexpr static float main_uvs[] = { 0, 0, 1, 0, 0, 1, 1, 1 };

/// @note This enum must be kept in sync with the shader counterpart.
typedef enum VertexInputIndex {
  VertexInputIndexPosition = 0,
  VertexInputIndexTexCoords,
} VertexInputIndex;

/// @note This enum must be kept in sync with the shader counterpart.
typedef enum FragmentInputIndex {
  FragmentInputIndexTexture = 0,
} FragmentInputIndex;

NSString* content_shader = @
    R"msl(#include <metal_stdlib>
    #include <simd/simd.h>
    
    using namespace metal;
    
    typedef enum VertexInputIndex {
        VertexInputIndexPosition = 0,
        VertexInputIndexTexCoords,
    } VertexInputIndex;
    
    typedef enum FragmentInputIndex {
        FragmentInputIndexTexture = 0,
    } FragmentInputIndex;
    
    struct VertexOut {
        float4 position [[position]];
        float2 tex_coords;
    };
    
    vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                constant vector_float2 *position [[buffer(VertexInputIndexPosition)]],
                                constant vector_float2 *tex_coords [[buffer(VertexInputIndexTexCoords)]]) {
        VertexOut out;
        out.position = vector_float4(position[vertexID], 0.0, 1.0);
        // The v coordinate of the distortion mesh is reversed compared to what Metal expects, so we invert it.
        out.tex_coords = vector_float2(tex_coords[vertexID].x, 1.0 - tex_coords[vertexID].y);
        return out;
    }
    
    fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<half> colorTexture [[texture(0)]]) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        return float4(colorTexture.sample(textureSampler, in.tex_coords));
    })msl";

NSString* black_shader = @
    R"msl(#include <metal_stdlib>
    #include <simd/simd.h>
    
    using namespace metal;
    
    typedef enum VertexInputIndex {
        VertexInputIndexPosition = 0
    } VertexInputIndex;
    
    struct VertexOut {
        float4 position [[position]];
    };
    
    vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                constant vector_float2 *position [[buffer(VertexInputIndexPosition)]]) {
        VertexOut out;
        out.position = vector_float4(position[vertexID], 0.0, 1.0);
        return out;
    }
    
    fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
        return float4(0.0, 0.0, 1.0, 1.0);
    })msl";


simd_float4x4 unity_projection_matrix;

namespace holokit {
class HoloKitDisplayProvider {
public:
    HoloKitDisplayProvider(IUnityXRTrace* trace,
                           IUnityXRDisplayInterface* display)
        : trace_(trace), display_(display) {}
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    IUnityXRDisplayInterface* GetDisplay() { return display_; }
    
    void SetHandle(UnitySubsystemHandle handle) { handle_ = handle; }
    
    void SetMtlInterface(IUnityGraphicsMetal* mtl_interface) { metal_interface_ = mtl_interface; }
    
    void SetSecondDisplayColorBuffer(UnityRenderBuffer unity_render_buffer) { second_display_native_render_buffer_ptr_ = unity_render_buffer; }
    
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
        GetInstance()->GetDisplay()->RegisterProviderForGraphicsThread(
            handle, &gfx_thread_provider);
        
        // Register for callbacks on display provider.
        UnityXRDisplayProvider provider{NULL, NULL, NULL};
//        provider.UpdateDisplayState = [](UnitySubsystemHandle, void*, UnityXRDisplayState* state) -> UnitySubsystemErrorCode {
//            os_log_t log = os_log_create("com.DefaultCompany.Display", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
//            os_signpost_id_t spid = os_signpost_id_generate(log);
//            os_signpost_interval_begin(log, spid, "UpdateDisplayState");
//            state->reprojectionMode = kUnityXRReprojectionModeOrientationOnly;
//            NSLog(@"ReprojectionMode: %d", state->reprojectionMode);
//            os_signpost_interval_end(log, spid, "UpdateDisplayState");
//            return kUnitySubsystemErrorCodeSuccess;
//            //return GetInstance()->UpdateDisplayState(state);
//        };
        provider.QueryMirrorViewBlitDesc = [](UnitySubsystemHandle, void*, const UnityXRMirrorViewBlitInfo, UnityXRMirrorViewBlitDesc*) -> UnitySubsystemErrorCode {
            //os_log_t log = os_log_create("com.DefaultCompany.Display", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
            //os_signpost_id_t spid = os_signpost_id_generate(log);
            //os_signpost_interval_begin(log, spid, "QueryMirrorViewBlitDesc", "frame_count: %d, last_frame_time: %f, system_uptime: %f", frame_count, last_frame_time, [[NSProcessInfo processInfo] systemUptime]);
            //os_signpost_interval_end(log, spid, "QueryMirrorViewBlitDesc");
            return kUnitySubsystemErrorCodeFailure;
        };
        GetInstance()->GetDisplay()->RegisterProvider(handle, &provider);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode Start() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Start()", GetCurrentTime());
        
        rendering_mode_ = holokit::HoloKitApi::GetInstance()->GetRenderingMode();
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop() const {}
    
    void Shutdown() const {}
    
    UnitySubsystemErrorCode GfxThread_Start(
            UnityXRRenderingCapabilities* rendering_caps) const {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_Start()", GetCurrentTime());
        // Does the system use multi-pass rendering?
        rendering_caps->noSinglePassRenderingSupport = false;
        rendering_caps->invalidateRenderStateAfterEachCallback = true;
        // Unity will swap buffers for us after GfxThread_SubmitCurrentFrame()
        // is executed.
        rendering_caps->skipPresentToMainScreen = false;
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
#pragma mark - SubmitCurrentFrame()
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_SubmitCurrentFrame()", GetCurrentTime());
        
        //os_log_t log = os_log_create("com.DefaultCompany.Display", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
        //os_signpost_id_t spid = os_signpost_id_generate(log);
        //os_signpost_interval_begin(log, spid, "SubmitCurrentFrame", "frame_count: %d, last_frame_time: %f, system_uptime: %f", frame_count, last_frame_time, [[NSProcessInfo processInfo] systemUptime]);
        
        RenderContent2();
        if (holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session != NULL && holokit::HoloKitApi::GetInstance()->GetRenderingMode() == 2) {
            RenderAlignmentMarker();
        }
        
//        if (holokit::HoloKitApi::GetInstance()->IsSecondDisplayAvailable() && second_display_native_render_buffer_ptr_ != nullptr) {
//          //  RenderToSecondDisplay();
//        }
        
        ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
        //NSLog(@"[ar_recorder]: writer status %ld", (long)ar_session_delegate_controller.recorder.writer.status);
        if (ar_session_delegate_controller.isRecording) {
            //CVPixelBufferRef pixelBuffer = [ARRecorder convertIOSurfaceRefToCVPixelBufferRef:metal_color_textures_[0].iosurface];
            CVPixelBufferRef pixelBuffer = [ARRecorder convertMTLTextureToCVPixelBufferRef:metal_color_textures_[1]];
            CMTime time = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000);
            [ar_session_delegate_controller.recorder insert:pixelBuffer with:time];
            CVPixelBufferRelease(pixelBuffer);
        }
        
        //os_signpost_interval_end(log, spid, "SubmitCurrentFrame");
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    // Mimic how Google Cardboard does the rendering
    void RenderContent2() {
        if (!main_metal_setup_) {
            id<MTLDevice> mtl_device = metal_interface_->MetalDevice();
            // Compile Metal library
            id<MTLLibrary> mtl_library = [mtl_device newLibraryWithSource:content_shader
                                                                  options:nil
                                                                    error:nil];
            if (mtl_library == nil) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Failed to compile Metal content library.");
                return;
            }
            id<MTLFunction> vertex_function = [mtl_library newFunctionWithName:@"vertexShader"];
            id<MTLFunction> fragment_function = [mtl_library newFunctionWithName:@"fragmentShader"];
            
            // Create pipeline
            MTLRenderPipelineDescriptor* mtl_render_pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
            mtl_render_pipeline_descriptor.vertexFunction = vertex_function;
            mtl_render_pipeline_descriptor.fragmentFunction = fragment_function;
            //mtl_render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            mtl_render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
            mtl_render_pipeline_descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            mtl_render_pipeline_descriptor.stencilAttachmentPixelFormat =
                MTLPixelFormatDepth32Float_Stencil8;
            mtl_render_pipeline_descriptor.sampleCount = 1;
            // Blending options
            mtl_render_pipeline_descriptor.colorAttachments[0].blendingEnabled = YES;
            mtl_render_pipeline_descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            mtl_render_pipeline_descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            mtl_render_pipeline_descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            mtl_render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
            mtl_render_pipeline_descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            mtl_render_pipeline_descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
            
            main_render_pipeline_state_ = [mtl_device newRenderPipelineStateWithDescriptor:mtl_render_pipeline_descriptor error:nil];
            if (mtl_render_pipeline_descriptor == nil) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Failed to create Metal content render pipeline.");
                return;
            }
            main_metal_setup_ = true;
            
//            ARRecorder *ar_recorder = [[ARRecorder alloc] init];
//            NSLog(@"fuck %@", [ar_recorder newVideoPath]);
        }
        
        id<MTLRenderCommandEncoder> mtl_render_command_encoder =
            (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [mtl_render_command_encoder setRenderPipelineState:main_render_pipeline_state_];
        [mtl_render_command_encoder setVertexBytes:main_vertices length:sizeof(main_vertices) atIndex:VertexInputIndexPosition];
        [mtl_render_command_encoder setVertexBytes:main_uvs length:sizeof(main_uvs) atIndex:VertexInputIndexTexCoords];
        [mtl_render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:FragmentInputIndexTexture];
        [mtl_render_command_encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                                       vertexStart:0
                                       vertexCount:4];
    }

    void RenderToSecondDisplay() {
        NSLog(@"[display]: render to second display");
        id<MTLRenderCommandEncoder> mtl_render_command_encoder =
            (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        
        MTLRenderPassDescriptor *mtl_render_pass_descriptor = metal_interface_->CurrentRenderPassDescriptor();
        id<MTLTexture> original_texture = mtl_render_pass_descriptor.colorAttachments[0].texture;
        // Force Metal to draw to the second display's color buffer.
        mtl_render_pass_descriptor.colorAttachments[0].texture = metal_interface_->TextureFromRenderBuffer(second_display_native_render_buffer_ptr_);
        
        [mtl_render_command_encoder setRenderPipelineState:main_render_pipeline_state_];
        [mtl_render_command_encoder setVertexBytes:main_vertices length:sizeof(main_vertices) atIndex:VertexInputIndexPosition];
        [mtl_render_command_encoder setVertexBytes:main_uvs length:sizeof(main_uvs) atIndex:VertexInputIndexTexCoords];
        [mtl_render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:FragmentInputIndexTexture];
        //[mtl_render_command_encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        
        mtl_render_pass_descriptor.colorAttachments[0].texture = original_texture;
    }
    
    void RenderContent() {
        // Metal initialization is expensive and we only want to run it once.
        if (!main_metal_setup_) {
            id<MTLDevice> mtl_device = metal_interface_->MetalDevice();
            
            // set up buffers
            main_vertex_buffer_ = [mtl_device newBufferWithBytes:vdata length:sizeof(vdata) options:MTLResourceOptionCPUCacheModeDefault];
            main_index_buffer_ = [mtl_device newBufferWithBytes:idata length:sizeof(idata) options:MTLResourceOptionCPUCacheModeDefault];
            // Set up library and functions
            id<MTLLibrary> lib = [mtl_device newLibraryWithSource:side_by_side_shader options:nil error:nil];
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
            //render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
            render_pipeline_descriptor.colorAttachments[0].blendingEnabled = YES;
            render_pipeline_descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            render_pipeline_descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            render_pipeline_descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            //render_pipeline_descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero; // MTLBlendFactorSourceAlpha;
            // TODO: this pamameter is vital.
            //render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
            //render_pipeline_descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorZero;// MTLBlendFactorOneMinusSourceAlpha;

            main_render_pipeline_state_ = [mtl_device newRenderPipelineStateWithDescriptor:render_pipeline_descriptor error:nil];
            main_metal_setup_ = true;
        }

        id<MTLRenderCommandEncoder> render_command_encoder = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [render_command_encoder setRenderPipelineState:main_render_pipeline_state_];
        [render_command_encoder setCullMode:MTLCullModeNone];
        [render_command_encoder setVertexBuffer:main_vertex_buffer_ offset:0 atIndex:0];
        [render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:0];
#if SIDE_BY_SIDE
        [render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:1];
#else
        [render_command_encoder setFragmentTexture:metal_color_textures_[1] atIndex:1];
#endif
        [render_command_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:main_index_buffer_ indexBufferOffset:0];
    }
    
    void RenderAlignmentMarker() {
        if (!second_metal_setup_) {
            id<MTLDevice> mtl_device = metal_interface_->MetalDevice();
            vertex_data[0] = vertex_data[4] = holokit::HoloKitApi::GetInstance()->GetHorizontalAlignmentMarkerOffset();
            
            second_vertex_buffer_ = [mtl_device newBufferWithBytes:vertex_data length:sizeof(vertex_data) options:MTLResourceOptionCPUCacheModeDefault];
            second_vertex_buffer_.label = @"vertices";
            //id<MTLBuffer> vertex_color_buffer = [mtl_device_ newBufferWithBytes:vertex_color_data length:sizeof(vertex_color_data) options:MTLResourceOptionCPUCacheModeDefault];
            //vertex_color_buffer.label = @"colors";
            
            id<MTLLibrary> lib = [mtl_device newLibraryWithSource:myShader options:nil error:nil];
            id<MTLFunction> vertex_function = [lib newFunctionWithName:@"passThroughVertex"];
            id<MTLFunction> fragment_function = [lib newFunctionWithName:@"passThroughFragment"];
            
            MTLRenderPipelineDescriptor* pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipeline_descriptor.vertexFunction = vertex_function;
            pipeline_descriptor.fragmentFunction = fragment_function;
            pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            pipeline_descriptor.sampleCount = 1;
            
            second_render_pipeline_state_ = [mtl_device newRenderPipelineStateWithDescriptor:pipeline_descriptor error:nil];
            second_metal_setup_ = true;
        }
        
        id<MTLRenderCommandEncoder> command_encoder = (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [command_encoder setRenderPipelineState:second_render_pipeline_state_];
        [command_encoder setVertexBuffer:second_vertex_buffer_ offset:0 atIndex:0];
        //[command_encoder setVertexBuffer:vertex_color_buffer offset:0 atIndex:1];
        [command_encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:(sizeof(vertex_data) / sizeof(float))];
    }

#pragma mark - PopulateNextFrame()
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()", GetCurrentTime());
        //WORKAROUND_SKIP_FIRST_FRAME();

        // BlockUntilUnityShouldStartSubmittingRenderingCommands();
        
        // Reference: https://stackoverflow.com/questions/62667953/can-i-set-signposts-before-and-after-a-call-in-objective-c
        //os_log_t log = os_log_create("com.DefaultCompany.Display", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
        //os_signpost_id_t spid = os_signpost_id_generate(log);
        //os_signpost_interval_begin(log, spid, "PopulateNextFrame", "frame_count: %d, last_frame_time: %f, system_uptime: %f", frame_count, last_frame_time, [[NSProcessInfo processInfo] systemUptime]);
        
        bool reallocate_textures = (unity_textures_.size() == 0);
//        if ((kUnityXRFrameSetupHintsChangedSinglePassRendering & frame_hints->changedFlags) != 0) {
//            NSLog(@"FUCK::kUnityXRFrameSetupHintsChangedSinglePassRendering");
//            reallocate_textures = true;
//        }
//        if ((kUnityXRFrameSetupHintsChangedTextureResolutionScale & frame_hints->changedFlags) != 0) {
//            NSLog(@"FUCK::kUnityXRFrameSetupHintsChangedTextureResolutionScale");
//            //reallocate_textures = true;
//        }
//        if ((kUnityXRFrameSetuphintsChangedReprojectionMode & frame_hints->changedFlags) != 0) {
//            NSLog(@"FUCK::kUnityXRFrameSetuphintsChangedReprojectionMode");
//            // App wants different reprojection mode, configure compositor if possible.
//        }
        
        // If the rendering mode has been changed
        if (rendering_mode_ != holokit::HoloKitApi::GetInstance()->GetRenderingMode()) {
            HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Rendering mode switched.", GetCurrentTime());
            rendering_mode_ = holokit::HoloKitApi::GetInstance()->GetRenderingMode();
            reallocate_textures = true;
        }

        if (reallocate_textures) {
            DestroyTextures();
            // The second texture is for the invisible second camera.
            int num_textures = 1 + 1;
            CreateTextures(num_textures);
        }
        
        // AR mode rendering
        if (rendering_mode_ != RenderingMode::XRMode || refresh_texture_) {
            next_frame->renderPassesCount = 1;
            
            auto& render_pass = next_frame->renderPasses[0];
            render_pass.textureId = unity_textures_[0];
            render_pass.renderParamsCount = 1;
            render_pass.cullingPassIndex = 0;
            
            auto& culling_pass = next_frame->cullingPasses[0];
            culling_pass.separation = 0.064f;
            
            auto& render_params = render_pass.renderParams[0];
            // view matrix
            UnityXRVector3 position;
            if (refresh_texture_) {
                position = UnityXRVector3 { 0, 100, 0 };
            } else {
                position = UnityXRVector3 { 0, 0, 0 };
            }
            UnityXRVector4 rotation = UnityXRVector4 { 0, 0, 0, 1 };
            UnityXRPose pose = { position, rotation };
            render_params.deviceAnchorToEyePose = culling_pass.deviceAnchorToCullingPose = pose;
            // get ARKit projection matrix
            simd_float4x4 projection_matrix = holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session.currentFrame.camera.projectionMatrix;
            render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
            // Make sure we can see the splash screen when ar session is not initialized.
            if (holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session == NULL) {
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(0));
            } else {
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = Float4x4ToUnityXRMatrix(projection_matrix);
            }
            render_params.viewportRect = {
                0.0f,                    // x
                0.0f,                    // y
                1.0f,                    // width
                1.0f                     // height
            };
            refresh_texture_ = false;
            return kUnitySubsystemErrorCodeSuccess;
        }
        
        // CHANGE THIS TO SWITCH BETWEEN RENDERING MODES
        bool single_pass_rendering = false;
        // Frame hints tells us if we should setup our renderpasses with a single pass
        if (!single_pass_rendering)
        {
            
            if (holokit::HoloKitApi::GetInstance()->IsSecondDisplayAvailable()) {
                next_frame->renderPassesCount = NUM_RENDER_PASSES + 1;
            } else {
                next_frame->renderPassesCount = NUM_RENDER_PASSES;
            }
            
            for (int pass = 0; pass < next_frame->renderPassesCount; ++pass)
            {
                auto& render_pass = next_frame->renderPasses[pass];
                
                if (pass == 2) {
                    // The extra pass for the invisible AR camera.
                    render_pass.textureId = unity_textures_[1];
                    //NSLog(@"texture id: %u", unity_textures_[1]);
                    render_pass.renderParamsCount = 1;
                    render_pass.cullingPassIndex = 0;
                    
                    auto& render_params = render_pass.renderParams[0];
                    UnityXRVector3 position = UnityXRVector3 { 0, 0, 0 };
                    UnityXRVector4 rotation = UnityXRVector4 { 0, 0, 0, 1 };
                    UnityXRPose pose = { position, rotation };
                    render_params.deviceAnchorToEyePose = pose;
                    render_params.projection.type = kUnityXRProjectionTypeMatrix;
                    simd_float4x4 projection_matrix = holokit::HoloKitApi::GetInstance()->GetArSessionHandler().session.currentFrame.camera.projectionMatrix;
                    render_params.projection.data.matrix = Float4x4ToUnityXRMatrix(projection_matrix);
                    render_params.viewportRect = {
                        0.0f,                    // x
                        0.0f,                    // y
                        1.0f,                    // width
                        1.0f                     // height
                    };
                } else {
                    // The first two passes for stereo rendering.
                    render_pass.textureId = unity_textures_[0];

                    render_pass.renderParamsCount = 1;
                    // Both passes share the same set of culling parameters.
                    render_pass.cullingPassIndex = 0;

                    auto& render_params = render_pass.renderParams[0];
                    render_params.deviceAnchorToEyePose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(pass));
                    render_params.projection.type = kUnityXRProjectionTypeMatrix;
                    render_params.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(pass));
                    render_params.viewportRect = Float4ToUnityXRRect(holokit::HoloKitApi::GetInstance()->GetViewportRect(pass));
                }
            }
            auto& culling_pass = next_frame->cullingPasses[0];
            culling_pass.separation = 0.064f;
            culling_pass.deviceAnchorToCullingPose = next_frame->renderPasses[0].renderParams[0].deviceAnchorToEyePose;
            culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
            culling_pass.projection.data.matrix = next_frame->renderPasses[0].renderParams[0].projection.data.matrix;
        }
        else
        {
            // Single-pass rendering
            next_frame->renderPassesCount = 1;
            auto& render_pass = next_frame->renderPasses[0];
            render_pass.textureId = unity_textures_[0];
            render_pass.renderParamsCount = 2;
            render_pass.cullingPassIndex = 0;
            for (int i = 0; i < 2; i++) {
                auto& render_params = render_pass.renderParams[i];
                render_params.deviceAnchorToEyePose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(i));
                render_params.projection.type = kUnityXRProjectionTypeMatrix;
                render_params.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(i));
                render_params.viewportRect = Float4ToUnityXRRect(holokit::HoloKitApi::GetInstance()->GetViewportRect(i));
            }
            auto& culling_pass = next_frame->cullingPasses[0];
            culling_pass.separation = 0.064f;
            culling_pass.deviceAnchorToCullingPose = next_frame->renderPasses[0].renderParams[0].deviceAnchorToEyePose;
            culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
            culling_pass.projection.data.matrix = next_frame->renderPasses[0].renderParams[0].projection.data.matrix;
        }
        //os_signpost_interval_end(log, spid, "PopulateNextFrame");
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
    }
    
#pragma mark - CreateTextures()
private:
    
    /// @brief Allocate unity textures.
    void CreateTextures(int num_textures) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f CreateTextures()", GetCurrentTime());
        
        id<MTLDevice> mtl_device = metal_interface_->MetalDevice();
        
        const int screen_width = holokit::HoloKitApi::GetInstance()->GetScreenWidth();
        const int screen_height = holokit::HoloKitApi::GetInstance()->GetScreenHeight();
        
        unity_textures_.resize(num_textures);
        native_color_textures_.resize(num_textures);
        native_depth_textures_.resize(num_textures);
        metal_color_textures_.resize(num_textures);
        io_surfaces_.resize(num_textures);
        
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
            io_surfaces_[i] = IOSurfaceCreate((CFDictionaryRef)color_surface_attribs);
            MTLTextureDescriptor* texture_color_buffer_descriptor = [[MTLTextureDescriptor alloc] init];
            texture_color_buffer_descriptor.textureType = MTLTextureType2D;
            texture_color_buffer_descriptor.width = screen_width;
            texture_color_buffer_descriptor.height = screen_height;
            texture_color_buffer_descriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
            //texture_color_buffer_descriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
            texture_color_buffer_descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView;
            metal_color_textures_[i] = [mtl_device newTextureWithDescriptor:texture_color_buffer_descriptor iosurface:io_surfaces_[i] plane:0];
            
            uint64_t color_buffer = reinterpret_cast<uint64_t>(io_surfaces_[i]);
            native_color_textures_[i] = reinterpret_cast<void*>(color_buffer);
            uint64_t depth_buffer = 0;
            native_depth_textures_[i] = reinterpret_cast<void*>(depth_buffer);
            
            //io_surfaces_[i] = color_surface;
            
            texture_descriptor.color.nativePtr = native_color_textures_[i];
            texture_descriptor.depth.nativePtr = native_depth_textures_[i];
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_descriptor, &unity_texture_id);
            unity_textures_[i] = unity_texture_id;
            
            refresh_texture_ = true;
        }
    }
    
    /// @brief Deallocate textures.
    void DestroyTextures() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f DestroyTextures()", GetCurrentTime());
        
        for (int i = 0; i < unity_textures_.size(); i++) {
            if(unity_textures_[i] != 0) {
                display_->DestroyTexture(handle_, unity_textures_[i]);
                native_color_textures_[i] = nullptr;
                native_depth_textures_[i] = nullptr;
                metal_color_textures_[i] = nil;
                io_surfaces_[i] = nil;
            }
        }
        
        unity_textures_.clear();
        native_color_textures_.clear();
        metal_color_textures_.clear();
        io_surfaces_.clear();
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
    
    /// @brief HoloKit SDK API wrapper.
    std::unique_ptr<holokit::HoloKitApi> holokit_api_;
    
    /// @brief An array of UnityXRRenderTextureId.
    std::vector<UnityXRRenderTextureId> unity_textures_;
    
    /// @brief An array of native texture pointers.
    std::vector<void*> native_color_textures_;
    
    std::vector<void*> native_depth_textures_;
    
    /// @brief An array of metal textures.
    std::vector<id<MTLTexture>> metal_color_textures_;
    
    std::vector<IOSurfaceRef> io_surfaces_;
    
    /// @brief This value is set to true when Metal is initialized for the first time.
    bool main_metal_setup_ = false;
    
    /// @brief The render pipeline state for content rendering.
    id <MTLRenderPipelineState> main_render_pipeline_state_;
    
    /// @brief This value is used for rendering widgets.
    bool second_metal_setup_ = false;
    
    id <MTLBuffer> main_vertex_buffer_;
    
    id <MTLBuffer> main_index_buffer_;
    
    id <MTLBuffer> second_vertex_buffer_;
    
    /// @brief The render pipeline state for rendering alignment marker.
    id <MTLRenderPipelineState> second_render_pipeline_state_;
    
    /// @brief If this value is set to true, the renderer
    bool refresh_texture_ = false;
    
    /// @brief Points to Metal interface.
    IUnityGraphicsMetal* metal_interface_;
    
    /// @brief This value is true if XR mode is enabled, false if AR mode is enabled.
    RenderingMode rendering_mode_;
    
    UnityRenderBuffer second_display_native_render_buffer_ptr_ = nullptr;
    
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
    holokit::HoloKitDisplayProvider::GetInstance().reset(new holokit::HoloKitDisplayProvider(trace, display));
    HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, "%f LoadDisplay()", GetCurrentTime());
    
    holokit::HoloKitDisplayProvider::GetInstance()->SetMtlInterface(xr_interfaces->Get<IUnityGraphicsMetal>());
    
    UnityLifecycleProvider display_lifecycle_handler;
    display_lifecycle_handler.userData = NULL;
    display_lifecycle_handler.Initialize = [](UnitySubsystemHandle handle, void*) -> UnitySubsystemErrorCode {
        return holokit::HoloKitDisplayProvider::GetInstance()->Initialize(handle);
    };
    display_lifecycle_handler.Start = [](UnitySubsystemHandle, void*) -> UnitySubsystemErrorCode {
        return holokit::HoloKitDisplayProvider::GetInstance()->Start();
    };
    display_lifecycle_handler.Stop = [](UnitySubsystemHandle, void*) -> void {
        return holokit::HoloKitDisplayProvider::GetInstance()->Stop();
    };
    display_lifecycle_handler.Shutdown = [](UnitySubsystemHandle, void*) -> void {
        return holokit::HoloKitDisplayProvider::GetInstance()->Shutdown();
    };
    
    // the names do matter
    // The parameters passed to RegisterLifecycleProvider must match the name and id fields in your manifest file.
    // see https://docs.unity3d.com/Manual/xrsdk-provider-setup.html
    return holokit::HoloKitDisplayProvider::GetInstance()->GetDisplay()->RegisterLifecycleProvider("HoloKit XR Plugin", "HoloKit Display", &display_lifecycle_handler);
}

void UnloadDisplay() { holokit::HoloKitDisplayProvider::GetInstance().reset(); }

extern "C" {

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
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

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetSecondDisplayNativeRenderBufferPtr(UnityRenderBuffer unity_render_buffer) {
    holokit::HoloKitDisplayProvider::GetInstance()->SetSecondDisplayColorBuffer(unity_render_buffer);
}

} // extern "C"
