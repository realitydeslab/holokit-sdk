#include <array>
#include <cassert>
#include <map>
#include <memory>

#include "unity/xr_unity_plugin/holokit_xr_unity.h"
#include "unity/xr_provider/load.h"
#include "unity/xr_provider/math_tools.h"
#include "IUnityInterface.h"
#include "IUnityGraphics.h"

#include "XR/IUnityXRDisplay.h"
#include "XR/IUnityXRTrace.h"
#include "XR/UnitySubsystemTypes.h"

#include "unity/xr_dummy/printc.h"

#import "IUnityGraphicsMetal.h"
#import <Metal/Metal.h>


// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrDisplayProvider]: " message "\n", \
               ##__VA_ARGS__)

namespace {
// @brief Holds the implementation methods of UnityLifecycleProvider and
//        UnityXRDisplayGraphicsThreadProvider
class HoloKitDisplayProvider {
 public:
  HoloKitDisplayProvider(IUnityInterfaces* interfaces, IUnityXRTrace* trace,
                           IUnityXRDisplayInterface* display)
      : interfaces_(interfaces), trace_(trace), display_(display) {}

  IUnityInterfaces* GetInterfaces() { return interfaces_; }

  IUnityXRDisplayInterface* GetDisplay() { return display_; }

  IUnityXRTrace* GetTrace() { return trace_; }

  void SetHandle(UnitySubsystemHandle handle) { handle_ = handle; }

  UnitySubsystemErrorCode Initialize() const {
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode Start() const {
    return kUnitySubsystemErrorCodeSuccess;
  }

  void Stop() const {}

  void Shutdown() const {}

  UnitySubsystemErrorCode GfxThread_Start(
      UnityXRRenderingCapabilities* rendering_caps) const {
    // The display provider uses multipass redering.
    rendering_caps->noSinglePassRenderingSupport = true;
    rendering_caps->invalidateRenderStateAfterEachCallback = true;
    // Unity will swap buffers for us after GfxThread_SubmitCurrentFrame() is
    // executed.
    rendering_caps->skipPresentToMainScreen = false;
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame() {
    if (!is_initialized_) {
      HOLOKIT_DISPLAY_XR_TRACE_LOG(
          trace_, "Skip the rendering because HoloKit SDK is uninitialized.");
      return kUnitySubsystemErrorCodeFailure;
    }
    //holokit_api_->RenderEyesToDisplay(holokit_api_->GetBoundFramebuffer());
    //holokit_api_->RenderWidgets();
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode GfxThread_PopulateNextFrameDesc(
      const UnityXRFrameSetupHints* frame_hints,
      UnityXRNextFrameDesc* next_frame) {
    // Allocate new color texture descriptors if needed and update device
    // parameters in HoloKit SDK.
    if ((frame_hints->changedFlags &
         kUnityXRFrameSetupHintsChangedTextureResolutionScale) != 0 ||
        !is_initialized_ ||
        holokit::unity::HoloKitApi::GetDeviceParametersChanged()) {
      // Create a new HoloKit SDK to clear previous truncated initializations
      // or just do it for the first time.
      HOLOKIT_DISPLAY_XR_TRACE_LOG(trace_, "Initializes HoloKit API.");
  //    holokit_api_.reset(new holokit::unity::HoloKitApi());
      // Deallocate old textures since we're completely reallocating new
      // textures for HoloKit SDK.
      for (auto&& tex : tex_map_) {
        display_->DestroyTexture(handle_, tex.second);
      }
      tex_map_.clear();

      holokit::unity::HoloKitApi::GetScreenParams(&width_, &height_);
 //     holokit_api_->UpdateDeviceParams();
      is_initialized_ = true;

      // Initialize texture descriptors.
      for (int i = 0; i < texture_descriptors_.size(); ++i) {
        texture_descriptors_[i] = {};
        texture_descriptors_[i].width = width_ / 2;
        texture_descriptors_[i].height = height_;
        texture_descriptors_[i].colorFormat = kUnityXRRenderTextureFormatBGRA32;
        texture_descriptors_[i].flags = 0;
        texture_descriptors_[i].depthFormat = kUnityXRDepthTextureFormat16bit;
          
        id<MTLDevice> metalDevice = GetInterfaces()->Get<IUnityGraphicsMetal>()->MetalDevice();
               
        MTLTextureDescriptor *color_texture_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width_ / 2 height:height_ mipmapped:NO];
        color_texture_desc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

        void* color_texture = (__bridge_retained void*) [metalDevice newTextureWithDescriptor:color_texture_desc];
        texture_descriptors_[i].color.nativePtr = color_texture;
          
        MTLTextureDescriptor *depth_texture_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth16Unorm width:width_/2 height:height_ mipmapped:NO];
        depth_texture_desc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

        void* depth_texture = (__bridge_retained void*) [metalDevice newTextureWithDescriptor:depth_texture_desc];
        texture_descriptors_[i].depth.nativePtr = depth_texture;
          UnityXRRenderTextureId unity_texture_id = 0;
          UnityXRRenderTextureDesc texture_descriptor = texture_descriptors_[i];
          display_->CreateTexture(handle_, &texture_descriptor,
                              &unity_texture_id);
//          tex_map_[color_texture] = unity_texture_id;
      }
    }
      
    // Setup render passes + texture ids for eye textures and layers.
    for (int i = 0; i < texture_descriptors_.size(); ++i) {
      // Sets the color texture ID to Unity texture descriptors.
        const int gl_colorname = i == 0 ? holokit_api_->GetLeftTextureId()
                                      : holokit_api_->GetRightTextureId();
        const int gl_depthname = i == 0 ? holokit_api_->GetLeftDepthBufferId()
                                      : holokit_api_->GetRightDepthBufferId();

      UnityXRRenderTextureId unity_texture_id = 0;
      auto found = tex_map_.find(gl_colorname);
      if (found == tex_map_.end()) {
        UnityXRRenderTextureDesc texture_descriptor = texture_descriptors_[i];
        texture_descriptor.color.nativePtr = ConvertInt(gl_colorname);
        texture_descriptor.depth.nativePtr = ConvertInt(gl_depthname);
        display_->CreateTexture(handle_, &texture_descriptor,
                                &unity_texture_id);
        tex_map_[gl_colorname] = unity_texture_id;
      } else {
        unity_texture_id = found->second;
      }
      next_frame->renderPasses[i].textureId = unity_texture_id;
    }

    {
      auto* left_eye_params = &next_frame->renderPasses[0].renderParams[0];
      auto* right_eye_params = &next_frame->renderPasses[1].renderParams[0];

      for (int i = 0; i < 2; ++i) {
        std::array<float, 4> fov;
        std::array<float, 16> eye_from_head;
        holokit_api_->GetEyeMatrices(i, eye_from_head.data(), fov.data());

        auto* eye_params = i == 0 ? left_eye_params : right_eye_params;
        // Update pose for rendering.
        eye_params->deviceAnchorToEyePose =
            holokit::unity::HoloKitTransformToUnityPose(eye_from_head);
        // Field of view and viewport.
        eye_params->viewportRect = frame_hints->appSetup.renderViewport;
        ConfigureFieldOfView(fov, &eye_params->projection);
      }

      // Configure the culling pass for the right eye (index == 1) to be the
      // same as the left eye (index == 0).
      next_frame->renderPasses[0].cullingPassIndex = 0;
      next_frame->renderPasses[1].cullingPassIndex = 0;
      next_frame->cullingPasses[0].deviceAnchorToCullingPose =
          left_eye_params->deviceAnchorToEyePose;
      next_frame->cullingPasses[0].projection = left_eye_params->projection;
      // TODO(b/155084408): Properly document this constant.
      next_frame->cullingPasses[0].separation = 0.064f;
    }

    // Configure multipass rendering with one pass for each eye.
    next_frame->renderPassesCount = 2;
    next_frame->renderPasses[0].renderParamsCount = 1;
    next_frame->renderPasses[1].renderParamsCount = 1;

    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode GfxThread_Stop() {
 //   holokit_api_.reset();
    is_initialized_ = false;
    return kUnitySubsystemErrorCodeSuccess;
  }

 private:
  /// @brief Converts @p i to a void*
  /// @param i An integer to convert to void*.
  /// @return A void* whose value is @p i.
  static void* ConvertInt(int i) {
    return reinterpret_cast<void*>(static_cast<intptr_t>(i));
  }

  /// @brief Loads Unity @p projection eye params from HoloKit field of view.
  /// @details Sets Unity @p projection to use half angles as HoloKit reported
  ///          field of view angles.
  /// @param[in] holokit_fov A float vector containing
  ///            [left, right, bottom, top] angles in radians.
  /// @param[out] project A Unity projection structure pointer to load.
  static void ConfigureFieldOfView(const std::array<float, 4>& holokit_fov,
                                   UnityXRProjection* projection) {
    projection->type = kUnityXRProjectionTypeHalfAngles;
    projection->data.halfAngles.bottom = -std::abs(tan(holokit_fov[2]));
    projection->data.halfAngles.top = std::abs(tan(holokit_fov[3]));
    projection->data.halfAngles.left = -std::abs(tan(holokit_fov[0]));
    projection->data.halfAngles.right = std::abs(tan(holokit_fov[1]));
  }

  /// @brief Points to Unity interfaces.
  IUnityInterfaces* interfaces_ = nullptr;
    
  /// @brief Points to Unity XR Trace interface.
  IUnityXRTrace* trace_ = nullptr;

  /// @brief Points to Unity XR Display interface.
  IUnityXRDisplayInterface* display_ = nullptr;

  /// @brief Opaque Unity pointer type passed between plugins.
  UnitySubsystemHandle handle_;

  /// @brief Tracks HoloKit API initialization status. It is set to true once
  /// the HoloKitApi::UpdateDeviceParams() is called and returns true.
  bool is_initialized_ = false;

  /// @brief Screen width in pixels.
  int width_;

  /// @brief Screen height in pixels.
  int height_;

  /// @brief HoloKit SDK API wrapper.
  std::unique_ptr<holokit::unity::HoloKitApi> holokit_api_;

  /// @brief Unity XR texture descriptors.
  std::array<UnityXRRenderTextureDesc, 2> texture_descriptors_{};

  /// @brief Map to link HoloKit API and Unity XR texture IDs.
  std::map<int, UnityXRRenderTextureId> tex_map_{};
};

std::unique_ptr<HoloKitDisplayProvider> display_provider;

}  // namespace

/// @brief Initializes the display subsystem.
///
/// @details Loads and configures a UnityXRDisplayGraphicsThreadProvider and
///          UnityXRDisplayProvider with pointers to `display_provider`'s
///          methods.
/// @param handle Opaque Unity pointer type passed between plugins.
/// @return kUnitySubsystemErrorCodeSuccess when the registration is successful.
///         Otherwise, a value in UnitySubsystemErrorCode flagging the error.
static UnitySubsystemErrorCode UNITY_INTERFACE_API
DisplayInitialize(UnitySubsystemHandle handle, void*) {
  display_provider->SetHandle(handle);

  // Register for callbacks on the graphics thread.
  UnityXRDisplayGraphicsThreadProvider gfx_thread_provider{};
  gfx_thread_provider.userData = NULL;
  gfx_thread_provider.Start = [](UnitySubsystemHandle, void*,
                                 UnityXRRenderingCapabilities* rendering_caps)
                                -> UnitySubsystemErrorCode {
    return display_provider->GfxThread_Start(rendering_caps);
  };
    gfx_thread_provider.SubmitCurrentFrame = nullptr;
//    [](UnitySubsystemHandle,
//                                               void*) -> UnitySubsystemErrorCode {
//     return display_provider->GfxThread_SubmitCurrentFrame();
//  };
    gfx_thread_provider.PopulateNextFrameDesc = nullptr;
//    gfx_thread_provider.PopulateNextFrameDesc = [](UnitySubsystemHandle, void*, const UnityXRFrameSetupHints* frame_hints,
//         UnityXRNextFrameDesc* next_frame) -> UnitySubsystemErrorCode {
//        return display_provider->GfxThread_PopulateNextFrameDesc(frame_hints,
//                                                                    next_frame);
//    };
  gfx_thread_provider.BlitToMirrorViewRenderTarget = nullptr;

  gfx_thread_provider.Stop = [](UnitySubsystemHandle,
                                void*) -> UnitySubsystemErrorCode {
    return display_provider->GfxThread_Stop();
  };
  display_provider->GetDisplay()->RegisterProviderForGraphicsThread(
      handle, &gfx_thread_provider);

  UnityXRDisplayProvider provider{NULL, NULL, NULL};
  display_provider->GetDisplay()->RegisterProvider(handle, &provider);
    
  return display_provider->Initialize();
}

/// @brief Loads a UnityLifecycleProvider for the display provider.
///
/// @details Gets the trace and display interfaces from @p xr_interfaces and
///          initializes the UnityLifecycleProvider's callbacks with references
///          to `display_provider`'s methods. The subsystem is "Display", and
///          the plugin is "HoloKit".
/// @param xr_interfaces Unity XR interface provider to create the display
///          subsystem.
/// @return kUnitySubsystemErrorCodeSuccess when the registration is successful.
///         Otherwise, a value in UnitySubsystemErrorCode flagging the error.
UnitySubsystemErrorCode LoadDisplay(IUnityInterfaces* xr_interfaces) {
    
    
  auto* display = xr_interfaces->Get<IUnityXRDisplayInterface>();
  if (display == NULL) {
    return kUnitySubsystemErrorCodeFailure;
  }
  auto* trace = xr_interfaces->Get<IUnityXRTrace>();
  if (trace == NULL) {
    return kUnitySubsystemErrorCodeFailure;
  }
  auto* graphics = xr_interfaces->Get<IUnityGraphics>();
        
      //TODO(should fix for more than METAL)
  if (graphics->GetRenderer() != kUnityGfxRendererMetal) {
     HOLOKIT_DISPLAY_XR_TRACE_LOG(trace,
                                  "Current render is not Metal");
     return kUnitySubsystemErrorCodeFailure;
  }

  auto* metalGraphics = xr_interfaces->Get<IUnityGraphicsMetal>();
  if (metalGraphics == NULL) {
     HOLOKIT_DISPLAY_XR_TRACE_LOG(trace,
                                  "cannot get metal");
     return kUnitySubsystemErrorCodeFailure;
  }
    
  display_provider.reset(new HoloKitDisplayProvider(xr_interfaces, trace, display));

  UnityLifecycleProvider display_lifecycle_handler;
  display_lifecycle_handler.userData = NULL;
  display_lifecycle_handler.Initialize = &DisplayInitialize;
  display_lifecycle_handler.Start = [](UnitySubsystemHandle,
                                       void*) -> UnitySubsystemErrorCode {
    HOLOKIT_DISPLAY_XR_TRACE_LOG(display_provider->GetTrace(),
                                     "Lifecycle started");
    return display_provider->Start();
  };
  display_lifecycle_handler.Stop = [](UnitySubsystemHandle, void*) -> void {
    HOLOKIT_DISPLAY_XR_TRACE_LOG(display_provider->GetTrace(),
                                     "Lifecycle stopped");
    display_provider->Stop();
  };
  display_lifecycle_handler.Shutdown = [](UnitySubsystemHandle, void*) -> void {
    HOLOKIT_DISPLAY_XR_TRACE_LOG(display_provider->GetTrace(),
                                     "Lifecycle shutdown");
    display_provider->Shutdown();
  };

  return display_provider->GetDisplay()->RegisterLifecycleProvider(
      "HoloKit XR Plugin", "HoloKit-Display", &display_lifecycle_handler);
}
