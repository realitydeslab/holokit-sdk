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
#import <Metal/Metal.h>
#else
#define XR_METAL 0
#define XR_ANDROID 1
#endif

/// if this is 1, both render passes will render to a single texture.
/// Otherwise, they will render to two separate textures.
#define SIDE_BY_SIDE 1

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrDisplayProvider]: " message "\n", \
               ##__VA_ARGS__)

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
    
    /// @brief Initializes the display subsystem.
    ///
    /// @details Loads and configures a UnityXRDisplayGraphicsThreadProvider and
    ///         UnityXRDisplayProvider with pointers to `display_provider_`'s methods.
    /// @param handle Opaque Unity pointer type passed between plugins.
    /// @return kUnitySubsystemErrorCodeSuccess when the registration is
    ///         successful. Otherwise, a value in UnitySubsystemErrorCode flagging
    ///         the error.
    UnitySubsystemErrorCode Initialize(UnitySubsystemHandle handle) {
        XR_TRACE_LOG(trace_, "%f Initialize()\n", GetCurrentTime());
        
        SetHandle(handle);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode Start() const {
        XR_TRACE_LOG(trace_, "%f Start()\n", GetCurrentTime());
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop() const {}
    
    void Shutdown() const {}
    
    UnitySubsystemErrorCode GfxThread_Start(
            UnityXRRenderingCapabilities* rendering_caps) const {
        XR_TRACE_LOG(trace_, "%f GfxThread_Start()\n", GetCurrentTime());
        // Does the system use multi-pass rendering?
        rendering_caps->noSinglePassRenderingSupport = true;
        rendering_caps->invalidateRenderStateAfterEachCallback = true;
        // Unity will swap buffers for us after GfxThread_SubmitCurrentFrame()
        // is executed.
        rendering_caps->skipPresentToMainScreen = false;
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
        XR_TRACE_LOG(trace_, "%f GfxThread_SubmitCurrentFrame()\n", GetCurrentTime());
        
        // TODO: should we get native textures here?
        
        // TODO: do the draw call here
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(const UnityXRFrameSetupHints* frame_hints, UnityXRNextFrameDesc* next_frame) {
        XR_TRACE_LOG(trace_, "%f GfxThread_PopulateNextFrameDesc()\n", GetCurrentTime());
        
        // Allocate new textures if needed
        if((frame_hints->changedFlags & kUnityXRFrameSetupHintsChangedTextureResolutionScale) != 0 || !is_initialized_) {
            // TODO: reset HoloKitApi
            
            // Deallocate old textures
            
        }
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
private:
    
    /// @brief Allocate unity textures.
    void CreateTextures(int num_textures, int texture_array_length, float requested_texture_scale) {
        XR_TRACE_LOG(trace_, "%f CreateTextures()\n", GetCurrentTime());
        
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
        XR_TRACE_LOG(trace_, "%f DestroyTextures()\n", GetCurrentTime());
        
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
