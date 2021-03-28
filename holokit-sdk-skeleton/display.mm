//
//  display.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <memory>

#include "IUnityXRTrace.h"
#include "IUnityXRDisplay.h"
#include "UnitySubsystemTypes.h"
#include "load.h"
#include "math_helpers.h"

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
    
    ///@brief Initializes the display subsystem.
    ///
    ///@details Loads and configures a UnityXRDisplayGraphicsThreadProvider and
    ///         UnityXRDisplayProvider with pointers to `display_provider_`'s methods.
    ///@param handle Opaque Unity pointer type passed between plugins.
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
    
    
    
private:
    
    ///@brief Points to Unity XR Trace interface.
    IUnityXRTrace* trace_ = nullptr;
    
    ///@brief Points to Unity XR Display interface.
    IUnityXRDisplayInterface* display_ = nullptr;
    
    ///@brief Opaque Unity pointer type passed between plugins.
    UnitySubsystemHandle handle_;
    
    ///@brief Screen width in pixels.
    int width_;
    
    ///@brief Screen height in pixels.
    int height_;
    
    static std::unique_ptr<HoloKitDisplayProvider> display_provider_;
};

std::unique_ptr<HoloKitDisplayProvider> HoloKitDisplayProvider::display_provider_;

std::unique_ptr<HoloKitDisplayProvider>& HoloKitDisplayProvider::GetInstance() {
    return display_provider_;
}
