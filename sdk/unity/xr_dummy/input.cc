#include <time.h>

#include <array>
#include <cmath>

#include "unity/xr_unity_plugin/holokit_xr_unity.h"
#include "unity/xr_provider/load.h"
#include "unity/xr_provider/math_tools.h"
#include "IUnityInterface.h"
#include "XR/IUnityXRInput.h"
#include "XR/IUnityXRTrace.h"
#include "XR/UnitySubsystemTypes.h"

#define HOLOKIT_INPUT_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrInputProvider]: " message "\n", \
               ##__VA_ARGS__)
namespace {

class HoloKitInputProvider {
 public:
  HoloKitInputProvider(IUnityXRTrace* trace, IUnityXRInputInterface* input)
      : trace_(trace), input_(input) {
  //  holokit_api_.reset(new holokit::unity::HoloKitApi());
  }

  IUnityXRInputInterface* GetInput() { return input_; }

  IUnityXRTrace* GetTrace() { return trace_; }

  void Init() {
      //holokit_api_->InitHeadTracker();
      HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "holokit_api_->InitHeadTracker()");
  }

  /// Callback executed when a subsystem should become active.
  UnitySubsystemErrorCode Start(UnitySubsystemHandle handle) {
    HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "Lifecycle started!!");
    input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHmd);
    input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHand);
   // holokit_api_->ResumeHeadTracker();
    return kUnitySubsystemErrorCodeSuccess;
  }

  /// Callback executed when a subsystem should become inactive.
  void Stop(UnitySubsystemHandle handle) {
    HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "Lifecycle stopped!!");
    input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHmd);
    input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHand);
      //    holokit_api_->PauseHeadTracker();
  }

  float s_Time = 0.0f;

  UnitySubsystemErrorCode Tick(UnityXRInputUpdateType updateType) {
//    std::array<float, 4> out_orientation;
//    std::array<float, 3> out_position;
//
 //   holokit_api_->GetHeadTrackerPose(out_position.data(),
 //                                      out_orientation.data());
    // TODO(b/151817737): Compute pose position within SDK with custom rotation.

     s_Time += 0.01f;
     if (s_Time > 1.0f)
         s_Time -= 2.0f;
  
      if (s_Time > -0.01 && s_Time < 0.01) {
          HOLOKIT_INPUT_XR_TRACE_LOG(GetTrace(), " Tick");
      }
      
      // Sets Unity Pose's rotation. Unity expects forward as positive z axis,
      // whereas OpenGL expects forward as negative z.
      head_pose_.position.x = s_Time;
      head_pose_.position.y = s_Time;
      head_pose_.position.z = s_Time;

      head_pose_.rotation.x = 0;
      head_pose_.rotation.y = 0;
      head_pose_.rotation.z = 0;
      head_pose_.rotation.w = 1;
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode FillDeviceDefinition(
      UnityXRInternalInputDeviceId device_id,
      UnityXRInputDeviceDefinition* definition) {
  
    if (device_id == kDeviceIdHoloKitHmd) {
        HOLOKIT_INPUT_XR_TRACE_LOG(GetTrace(), "FillDeviceDefinition %d", device_id);

        input_->DeviceDefinition_SetName(definition, "HoloKit HMD");
        input_->DeviceDefinition_SetCharacteristics(definition,
                                                    kHmdCharacteristics);
        input_->DeviceDefinition_SetManufacturer(definition, "Holo Interactive");

        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary,
                                                     kUnityXRInputFeatureUsageIsTracked);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates,
                                                     kUnityXRInputFeatureUsageTrackingState);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Center Eye Position", kUnityXRInputFeatureTypeAxis3D,
                                                     kUnityXRInputFeatureUsageCenterEyePosition);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Center Eye Rotation", kUnityXRInputFeatureTypeRotation,
            
                                                     kUnityXRInputFeatureUsageCenterEyeRotation);

        return kUnitySubsystemErrorCodeSuccess;
        
    } else if (device_id == kDeviceIdHoloKitHand) {
        HOLOKIT_INPUT_XR_TRACE_LOG(GetTrace(), "FillDeviceDefinition %d", device_id);

        input_->DeviceDefinition_SetName(definition, "HoloKit Hand");
        input_->DeviceDefinition_SetCharacteristics(definition, kHandCharacteristics);
        input_->DeviceDefinition_SetManufacturer(definition, "Holo Interactive");
        
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Wrist", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "ThumbStart", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Thumb1", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Thumb2", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "ThumbEnd", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "MidStart", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Mid1", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Mid2", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "MidEnd", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "RingStart", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Ring1", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Ring2", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "RingEnd", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "PinkyStart", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Pinky1", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Pinky2", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "PinkyEnd", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);
//        
//        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
//        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates, kUnityXRInputFeatureUsageTrackingState);
//        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Handedness", kUnityXRInputFeatureTypeDiscreteStates, kUnityXRInputFeatureUsageHandData);
//        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Air Tap", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//        

        
//        UnityXRInputFeatureIndex hand_structure = input_->DeviceDefinition_AddFeatureWithUsage(
//            definition, "Hand Indices", kUnityXRInputFeatureTypeHand, kUnityXRInputFeatureUsageHandData);
//        UnityXRInputFeatureIndex LeftHand = input_->DeviceDefinition_AddFeatureWithUsage(
//            definition, "LeftHand", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);

        
        return kUnitySubsystemErrorCodeSuccess;
        
    } else {
        return kUnitySubsystemErrorCodeFailure;
    }
  }

  UnitySubsystemErrorCode UpdateDeviceState(
      UnityXRInternalInputDeviceId device_id, UnityXRInputDeviceState* state) {
      
    if (device_id == kDeviceIdHoloKitHmd) {
        
        //HOLOKIT_INPUT_XR_TRACE_LOG(GetTrace(), "UpdateDeviceState %d", device_id);

        UnityXRInputFeatureIndex feature_index = 0;
        input_->DeviceState_SetBinaryValue(state, feature_index++, true);
        input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStatePosition | kUnityXRInputTrackingStateRotation);
        input_->DeviceState_SetAxis3DValue(state, feature_index++, head_pose_.position);
        input_->DeviceState_SetRotationValue(state, feature_index++, head_pose_.rotation);
        
        return kUnitySubsystemErrorCodeSuccess;
    } else if (device_id == kDeviceIdHoloKitHand) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(GetTrace(), "UpdateDeviceState kDeviceIdHoloKitHand %d", device_id);
        
        input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});
        input_->DeviceState_SetBoneValue(state, 20, UnityXRBone {.parentBoneIndex = 19, .position = {0, 0, 0}, .rotation = {0, 0, 0, 1}});

        UnityXRInputFeatureIndex feature_index = 21;
//        
//        input_->DeviceState_SetBinaryValue(state, feature_index++, true);
//        input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStateAll);
//        input_->DeviceState_SetDiscreteStateValue(state, feature_index++, 0); //handedness
//        input_->DeviceState_SetBinaryValue(state, feature_index++, false); //AirTag

        
        return kUnitySubsystemErrorCodeSuccess;
    }
    else {
        return kUnitySubsystemErrorCodeFailure;
    }
  }

  UnitySubsystemErrorCode QueryTrackingOriginMode(
      UnityXRInputTrackingOriginModeFlags* tracking_origin_mode) {
    *tracking_origin_mode = kUnityXRInputTrackingOriginModeDevice;
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode QuerySupportedTrackingOriginModes(
      UnityXRInputTrackingOriginModeFlags* supported_tracking_origin_modes) {
    *supported_tracking_origin_modes = kUnityXRInputTrackingOriginModeDevice;
    return kUnitySubsystemErrorCodeSuccess;
  }

  UnitySubsystemErrorCode HandleSetTrackingOriginMode(
      UnityXRInputTrackingOriginModeFlags tracking_origin_mode) {
    return tracking_origin_mode == kUnityXRInputTrackingOriginModeDevice
               ? kUnitySubsystemErrorCodeSuccess
               : kUnitySubsystemErrorCodeFailure;
  }

 private:
  static constexpr int kDeviceIdHoloKitHmd = 1234;
  static constexpr int kDeviceIdHoloKitHand = 4321;

  static constexpr UnityXRInputDeviceCharacteristics kHmdCharacteristics =
      static_cast<UnityXRInputDeviceCharacteristics>(
          kUnityXRInputDeviceCharacteristicsHeadMounted |
          kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    static constexpr UnityXRInputDeviceCharacteristics kHandCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
            kUnityXRInputDeviceCharacteristicsHandTracking);
    
  IUnityXRTrace* trace_ = nullptr;

  IUnityXRInputInterface* input_ = nullptr;

  UnityXRPose head_pose_;

  std::unique_ptr<holokit::unity::HoloKitApi> holokit_api_;
};

std::unique_ptr<HoloKitInputProvider> holokit_input_provider;
}  // anonymous namespace

/// Callback executed when a subsystem should initialize in preparation for
/// becoming active.
static UnitySubsystemErrorCode UNITY_INTERFACE_API
LifecycleInitialize(UnitySubsystemHandle handle, void* data) {
  HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider->GetTrace(),
                               "Lifecycle initialized");

  // Initializes XR Input Provider
  UnityXRInputProvider input_provider;
  input_provider.userData = nullptr;
  input_provider.Tick = [](UnitySubsystemHandle, void*,
                           UnityXRInputUpdateType updateType) {
    return holokit_input_provider->Tick(updateType);
  };
  input_provider.FillDeviceDefinition =
      [](UnitySubsystemHandle, void*, UnityXRInternalInputDeviceId device_id,
         UnityXRInputDeviceDefinition* definition) {
        return holokit_input_provider->FillDeviceDefinition(device_id,
                                                              definition);
      };
  input_provider.UpdateDeviceState =
      [](UnitySubsystemHandle, void*, UnityXRInternalInputDeviceId device_id,
         UnityXRInputUpdateType, UnityXRInputDeviceState* state) {
        return holokit_input_provider->UpdateDeviceState(device_id, state);
      };
  input_provider.HandleEvent = [](UnitySubsystemHandle, void*, unsigned int,
                                  UnityXRInternalInputDeviceId, void*,
                                  unsigned int) {
    HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider->GetTrace(),
                                 "No events to handle");
    return kUnitySubsystemErrorCodeSuccess;
  };
  input_provider.QueryTrackingOriginMode =
      [](UnitySubsystemHandle, void*,
         UnityXRInputTrackingOriginModeFlags* tracking_origin_mode) {
        return holokit_input_provider->QueryTrackingOriginMode(
            tracking_origin_mode);
      };
  input_provider.QuerySupportedTrackingOriginModes =
      [](UnitySubsystemHandle, void*,
         UnityXRInputTrackingOriginModeFlags* supported_tracking_origin_modes) {
        return holokit_input_provider->QuerySupportedTrackingOriginModes(
            supported_tracking_origin_modes);
      };
  input_provider.HandleSetTrackingOriginMode =
      [](UnitySubsystemHandle, void*,
         UnityXRInputTrackingOriginModeFlags tracking_origin_mode) {
        return holokit_input_provider->HandleSetTrackingOriginMode(
            tracking_origin_mode);
      };

  input_provider.HandleRecenter = nullptr;
  input_provider.HandleHapticImpulse = nullptr;
  input_provider.HandleHapticBuffer = nullptr;
  input_provider.QueryHapticCapabilities = nullptr;
  input_provider.HandleHapticStop = nullptr;
  holokit_input_provider->GetInput()->RegisterInputProvider(handle,
                                                            &input_provider);

  // Initializes HoloKit's Head Tracker module.
  holokit_input_provider->Init();

  return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode LoadInput(IUnityInterfaces* xr_interfaces) {
  auto* input = xr_interfaces->Get<IUnityXRInputInterface>();
  if (input == NULL) {
    return kUnitySubsystemErrorCodeFailure;
  }
  auto* trace = xr_interfaces->Get<IUnityXRTrace>();
  if (trace == NULL) {
    return kUnitySubsystemErrorCodeFailure;
  }
  holokit_input_provider.reset(new HoloKitInputProvider(trace, input));

  UnityLifecycleProvider input_lifecycle_handler;
  input_lifecycle_handler.userData = NULL;
  input_lifecycle_handler.Initialize = &LifecycleInitialize;
  input_lifecycle_handler.Start = [](UnitySubsystemHandle handle, void*) {
    HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider->GetTrace(),
                                      "Lifecycle started");
    return holokit_input_provider->Start(handle);
  };
  input_lifecycle_handler.Stop = [](UnitySubsystemHandle handle, void*) {
    HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider->GetTrace(),
                                   "Lifecycle stopped");
    return holokit_input_provider->Stop(handle);
  };
  input_lifecycle_handler.Shutdown = [](UnitySubsystemHandle handle, void*) {
    HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider->GetTrace(),
                                 "Lifecycle finished");
  };
  return input->RegisterLifecycleProvider("HoloKit XR Plugin", "HoloKit-Input",
                                          &input_lifecycle_handler);
}
