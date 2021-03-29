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

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrDisplayProvider]: " message "\n", \
               ##__VA_ARGS__)

namespace {
class HoloKitDisplayProvider {
public:
    HoloKitDisplayProvider(IUnityXRTrace* trace,
                           IUnityXRDisplayInterface* display)
        : trace_(trace), display_(display) {}
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    IUnityXRDisplayInterface* GetDisplay() { return display_; }
    
    void SetHandle(UnitySubsystemHandle handle) { handle_ = handle; }
    
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
        // TODO: fill this
        
        // currently we do not need blit
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
    
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_SubmitCurrentFrame()", GetCurrentTime());
        
        // TODO: should we get native textures here?
        
        // TODO: do the draw call here
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {
        HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()", GetCurrentTime());
        
        // Allocate new textures if needed
        if((frame_hints->changedFlags & kUnityXRFrameSetupHintsChangedTextureResolutionScale) != 0 || !is_initialized_) {
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
            
            for (int pass = 0; pass < 2; pass++){
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
                render_params.projection.type = culling_pass.projection.type = kUnityXRProjectionTypeMatrix;
                render_params.projection.data.matrix = culling_pass.projection.data.matrix = holokit_api_->GetProjectionMatrix(pass);
                
#if SIDE_BY_SIDE
                render_params.viewportRect = holokit_api_->GetViewportRect(pass);
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
        
        // TODO: improve this
        const int tex_width = (int)(2778.0f * requested_texture_scale);
        const int tex_height = (int)(1284.0f * requested_texture_scale);
        
        native_textures_.resize(num_textures);
        unity_textures_.resize(num_textures);
#if XR_METAL
        metal_textures_.resize(num_textures);
#endif
        
        for (int i = 0; i < num_textures; i++) {
            UnityXRRenderTextureDesc texture_desc;
            memset(&texture_desc, 0, sizeof(UnityXRRenderTextureDesc));
            
            texture_desc.colorFormat = kUnityXRRenderTextureFormatRGBA32;
            // we will query the pointer of unity created texture later
            texture_desc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            // TODO: do we need depth?
            texture_desc.depthFormat = kUnityXRDepthTextureFormat24bitOrGreater;
            texture_desc.depth.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
            texture_desc.width = tex_width;
            texture_desc.height = tex_height;
            texture_desc.textureArrayLength = texture_array_length;
            
            UnityXRRenderTextureId unity_texture_id;
            display_->CreateTexture(handle_, &texture_desc, &unity_texture_id);
            unity_textures_[i] = unity_texture_id;
        }
    }
    
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
    return HoloKitDisplayProvider::GetInstance()->GetDisplay()->RegisterLifecycleProvider("HoloKit XR Plugin", "HoloKit-Display", &display_lifecycle_handler);
}

void UnloadDisplay() { HoloKitDisplayProvider::GetInstance().reset(); }
