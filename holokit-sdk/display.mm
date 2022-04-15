//
//  display.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#import <memory>
#import <vector>

#import <os/log.h>
#import <os/signpost.h>

#import "IUnityXRTrace.h"
#import "IUnityXRDisplay.h"
#import "UnitySubsystemTypes.h"
#import "load.h"
#import "math_helpers.h"
#import "holokit_api.h"

#import "IUnityGraphicsMetal.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitDisplayProvider] " message "\n", \
               ##__VA_ARGS__)

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

NSString* quad_shader = @
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

typedef void (*SetARCameraBackground)(bool value);
SetARCameraBackground SetARCameraBackgroundDelegate = NULL;

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
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f Initialize()", GetCurrentTime());
        
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
        GetInstance()->GetDisplay()->RegisterProviderForGraphicsThread(handle, &gfx_thread_provider);
        
        // Register for callbacks on display provider.
        UnityXRDisplayProvider provider{NULL, NULL, NULL};
        provider.QueryMirrorViewBlitDesc = [](UnitySubsystemHandle, void*, const UnityXRMirrorViewBlitInfo, UnityXRMirrorViewBlitDesc*) -> UnitySubsystemErrorCode {
            return kUnitySubsystemErrorCodeFailure;
        };
        GetInstance()->GetDisplay()->RegisterProvider(handle, &provider);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode Start() {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Start");
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop() const {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Stop");
    }
    
    void Shutdown() const {}
    
    UnitySubsystemErrorCode GfxThread_Start(UnityXRRenderingCapabilities* rendering_caps) {

        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "GfxThread_Start");
        
        // Does the system use multi-pass rendering?
        rendering_caps->noSinglePassRenderingSupport = true;
        rendering_caps->invalidateRenderStateAfterEachCallback = false;
        // Unity will swap buffers for us after GfxThread_SubmitCurrentFrame() is executed.
        rendering_caps->skipPresentToMainScreen = false;
        
        // Allocate new textures when gfx thread starts.
        allocate_new_textures_ = true;
        frame_count_ = 0;
        // Disable AR background image
//        if (holokit::HoloKitApi::GetInstance()->GetStereoscopicRendering() && SetARCameraBackgroundDelegate) {
//            SetARCameraBackgroundDelegate(false);
//        }
//        if (SetARCameraBackgroundDelegate) {
//            SetARCameraBackgroundDelegate(false);
//        }
        holokit::HoloKitApi::GetInstance()->SetStereoscopicRendering(true);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
#pragma mark - SubmitCurrentFrame()
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {

        RenderContent();
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void RenderContent() {
        if (!metal_setup_) {
            id<MTLDevice> mtl_device = metal_interface_->MetalDevice();
            // Compile Metal library
            id<MTLLibrary> mtl_library = [mtl_device newLibraryWithSource:quad_shader
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
            mtl_render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            //mtl_render_pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
            mtl_render_pipeline_descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            mtl_render_pipeline_descriptor.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            mtl_render_pipeline_descriptor.sampleCount = 1;
            // Blending options
            mtl_render_pipeline_descriptor.colorAttachments[0].blendingEnabled = YES;
            mtl_render_pipeline_descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            mtl_render_pipeline_descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            mtl_render_pipeline_descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            mtl_render_pipeline_descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
            mtl_render_pipeline_descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            mtl_render_pipeline_descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
            
            metal_render_pipeline_state_ = [mtl_device newRenderPipelineStateWithDescriptor:mtl_render_pipeline_descriptor error:nil];
            if (mtl_render_pipeline_descriptor == nil) {
                HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Failed to create Metal render pipeline.");
                return;
            }
            metal_setup_ = true;
        }
        
        id<MTLRenderCommandEncoder> mtl_render_command_encoder =
            (id<MTLRenderCommandEncoder>)metal_interface_->CurrentCommandEncoder();
        [mtl_render_command_encoder setRenderPipelineState:metal_render_pipeline_state_];
        [mtl_render_command_encoder setVertexBytes:main_vertices length:sizeof(main_vertices) atIndex:VertexInputIndexPosition];
        [mtl_render_command_encoder setVertexBytes:main_uvs length:sizeof(main_uvs) atIndex:VertexInputIndexTexCoords];
        [mtl_render_command_encoder setFragmentTexture:metal_color_textures_[0] atIndex:FragmentInputIndexTexture];
        [mtl_render_command_encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    }

#pragma mark - PopulateNextFrame()
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {

        if (allocate_new_textures_) {
            DestroyTextures();
            CreateTextures(1);
            allocate_new_textures_ = false;
        }
        
        if (holokit::HoloKitApi::GetInstance()->GetSinglePassRendering())
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
            culling_pass.separation = holokit::HoloKitApi::GetInstance()->kUserInterpupillaryDistance;
            culling_pass.deviceAnchorToCullingPose = next_frame->renderPasses[0].renderParams[0].deviceAnchorToEyePose;
            culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
            culling_pass.projection.data.matrix = next_frame->renderPasses[0].renderParams[0].projection.data.matrix;
        }
        else
        {
            // 2-pass rendering
            next_frame->renderPassesCount = 2;
            // 0 for the left eye and 1 for the right eye.
            for (int pass = 0; pass < next_frame->renderPassesCount; pass++)
            {
                auto& render_pass = next_frame->renderPasses[pass];
                
                render_pass.textureId = unity_textures_[0];
                render_pass.renderParamsCount = 1;
                render_pass.cullingPassIndex = pass;
                
                auto& render_params = render_pass.renderParams[0];
                // Render a black image for the 10 frames to avoid viewport glitch.
                // This glitch only happened on the left viewport.
                if (pass == 0 && frame_count_ < 10) {
                    frame_count_++;
                    UnityXRVector3 sky_position = UnityXRVector3 { 0, 999, 0 };
                    UnityXRVector4 sky_rotation = UnityXRVector4 { 0, 0, 0, 1 };
                    UnityXRPose sky_pose = { sky_position, sky_rotation };
                    render_params.deviceAnchorToEyePose = sky_pose;
                } else {
                    render_params.deviceAnchorToEyePose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(pass));
                }
                //render_params.deviceAnchorToEyePose = EyePositionToUnityXRPose(holokit::HoloKitApi::GetInstance()->GetEyePosition(pass));
                render_params.projection.type = kUnityXRProjectionTypeMatrix;
                render_params.projection.data.matrix = Float4x4ToUnityXRMatrix(holokit::HoloKitApi::GetInstance()->GetProjectionMatrix(pass));
                render_params.viewportRect = Float4ToUnityXRRect(holokit::HoloKitApi::GetInstance()->GetViewportRect(pass));
                
                // Do culling for each eye seperately.
                auto& culling_pass = next_frame->cullingPasses[pass];
                culling_pass.separation = holokit::HoloKitApi::GetInstance()->kUserInterpupillaryDistance;
                culling_pass.deviceAnchorToCullingPose = next_frame->renderPasses[pass].renderParams[0].deviceAnchorToEyePose;
                culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
                culling_pass.projection.data.matrix = next_frame->renderPasses[pass].renderParams[0].projection.data.matrix;
            }
        }
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_Stop() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "GfxThread_Stop");
        
        // Enable AR background image
//        if (holokit::HoloKitApi::GetInstance()->GetStereoscopicRendering() && SetARCameraBackgroundDelegate) {
//            SetARCameraBackgroundDelegate(true);
//        }
//        if (SetARCameraBackgroundDelegate) {
//            SetARCameraBackgroundDelegate(true);
//        }
        holokit::HoloKitApi::GetInstance()->SetStereoscopicRendering(false);
        
        return kUnitySubsystemErrorCodeSuccess;
    }

    UnitySubsystemErrorCode UpdateDisplayState(UnityXRDisplayState* state) {
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc * blitDescriptor) {
        return kUnitySubsystemErrorCodeFailure;
    }
    
#pragma mark - CreateTextures()
private:
    
    /// @brief Allocate unity textures.
    void CreateTextures(int num_textures) {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f CreateTextures()", GetCurrentTime());
        
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
            
            texture_descriptor.color.nativePtr = native_color_textures_[i];
            texture_descriptor.depth.nativePtr = native_depth_textures_[i];
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_descriptor, &unity_texture_id);
            unity_textures_[i] = unity_texture_id;
        }
    }
    
    /// @brief Deallocate textures.
    void DestroyTextures() {
        //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f DestroyTextures()", GetCurrentTime());
        
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
    
    /// @brief An array of UnityXRRenderTextureId.
    std::vector<UnityXRRenderTextureId> unity_textures_;
    
    /// @brief An array of native texture pointers.
    std::vector<void*> native_color_textures_;
    
    std::vector<void*> native_depth_textures_;
    
    /// @brief An array of metal textures.
    std::vector<id<MTLTexture>> metal_color_textures_;
    
    std::vector<IOSurfaceRef> io_surfaces_;
    
    /// @brief This value is set to true when Metal is initialized for the first time.
    bool metal_setup_ = false;
    
    /// @brief The render pipeline state for content rendering.
    id <MTLRenderPipelineState> metal_render_pipeline_state_;
    
    int frame_count_;
    
    bool allocate_new_textures_ = true;
    
    /// @brief Points to Metal interface.
    IUnityGraphicsMetal* metal_interface_;
    
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
    //HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, "%f LoadDisplay()", GetCurrentTime());
    
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
UnityHoloKit_SetSetARCameraBackgroundDelegate(SetARCameraBackground callback) {
    SetARCameraBackgroundDelegate = callback;
}

} // extern "C"
