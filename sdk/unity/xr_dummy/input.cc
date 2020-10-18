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
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
        input_->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates, kUnityXRInputFeatureUsageTrackingState);

        
//        UnityXRInputFeatureIndex hand_structure = input_->DeviceDefinition_AddFeatureWithUsage(
//            definition, "Hand Indices", kUnityXRInputFeatureTypeHand, kUnityXRInputFeatureUsageHandData);
        UnityXRInputFeatureIndex LeftHand = input_->DeviceDefinition_AddFeatureWithUsage(
            definition, "LeftHand", kUnityXRInputFeatureTypeBone, kUnityXRInputFeatureUsageHandData);

        
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
        
        UnityXRInputFeatureIndex feature_index = 0;
        UnityXRBone bone;
        bone.parentBoneIndex = 0;
        bone.position = {0, 0, 0};
        bone.rotation = {0, 0, 0, 1};
        
        input_->DeviceState_SetBinaryValue(state, feature_index++, true);
        input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStateAll);
        input_->DeviceState_SetBoneValue(state, feature_index++, bone);
        
        return kUnitySubsystemErrorCodeSuccess;
        //        UnityXRHand hand;

//
//        /*
//         LeftHand = 22, // parent: LeftForearm [21]
//         LeftHandIndexStart = 23, // parent: LeftHand [22]
//         LeftHandIndex1 = 24, // parent: LeftHandIndexStart [23]
//         LeftHandIndex2 = 25, // parent: LeftHandIndex1 [24]
//         LeftHandIndex3 = 26, // parent: LeftHandIndex2 [25]
//         LeftHandIndexEnd = 27, // parent: LeftHandIndex3 [26]
//         LeftHandMidStart = 28, // parent: LeftHand [22]
//         LeftHandMid1 = 29, // parent: LeftHandMidStart [28]
//         LeftHandMid2 = 30, // parent: LeftHandMid1 [29]
//         LeftHandMid3 = 31, // parent: LeftHandMid2 [30]
//         LeftHandMidEnd = 32, // parent: LeftHandMid3 [31]
//         LeftHandPinkyStart = 33, // parent: LeftHand [22]
//         LeftHandPinky1 = 34, // parent: LeftHandPinkyStart [33]
//         LeftHandPinky2 = 35, // parent: LeftHandPinky1 [34]
//         LeftHandPinky3 = 36, // parent: LeftHandPinky2 [35]
//         LeftHandPinkyEnd = 37, // parent: LeftHandPinky3 [36]
//         LeftHandRingStart = 38, // parent: LeftHand [22]
//         LeftHandRing1 = 39, // parent: LeftHandRingStart [38]
//         LeftHandRing2 = 40, // parent: LeftHandRing1 [39]
//         LeftHandRing3 = 41, // parent: LeftHandRing2 [40]
//         LeftHandRingEnd = 42, // parent: LeftHandRing3 [41]
//         LeftHandThumbStart = 43, // parent: LeftHand [22]
//         LeftHandThumb1 = 44, // parent: LeftHandThumbStart [43]
//         LeftHandThumb2 = 45, // parent: LeftHandThumb1 [44]
//         LeftHandThumbEnd = 46, // parent: LeftHandThumb2 [45]
//
//        RightHand = 66, // parent: RightForearm [65]
//        RightHandIndexStart = 67, // parent: RightHand [66]
//        RightHandIndex1 = 68, // parent: RightHandIndexStart [67]
//        RightHandIndex2 = 69, // parent: RightHandIndex1 [68]
//        RightHandIndex3 = 70, // parent: RightHandIndex2 [69]
//        RightHandIndexEnd = 71, // parent: RightHandIndex3 [70]
//        RightHandMidStart = 72, // parent: RightHand [66]
//        RightHandMid1 = 73, // parent: RightHandMidStart [72]
//        RightHandMid2 = 74, // parent: RightHandMid1 [73]
//        RightHandMid3 = 75, // parent: RightHandMid2 [74]
//        RightHandMidEnd = 76, // parent: RightHandMid3 [75]
//        RightHandPinkyStart = 77, // parent: RightHand [66]
//        RightHandPinky1 = 78, // parent: RightHandPinkyStart [77]
//        RightHandPinky2 = 79, // parent: RightHandPinky1 [78]
//        RightHandPinky3 = 80, // parent: RightHandPinky2 [79]
//        RightHandPinkyEnd = 81, // parent: RightHandPinky3 [80]
//        RightHandRingStart = 82, // parent: RightHand [66]
//        RightHandRing1 = 83, // parent: RightHandRingStart [82]
//        RightHandRing2 = 84, // parent: RightHandRing1 [83]
//        RightHandRing3 = 85, // parent: RightHandRing2 [84]
//        RightHandRingEnd = 86, // parent: RightHandRing3 [85]
//        RightHandThumbStart = 87, // parent: RightHand [66]
//        RightHandThumb1 = 88, // parent: RightHandThumbStart [87]
//        RightHandThumb2 = 89, // parent: RightHandThumb1 [88]
//        RightHandThumbEnd = 90, // parent: RightHandThumb2 [89]
//        */
//
//        hand.fingerBonesIndices[UnityXRFingerThumb] = {0, 1, 2};
//        hand.fingerBonesIndices[UnityXRFingerIndex] = {0, 1, 2};
//        hand.fingerBonesIndices[UnityXRFingerMiddle] = {0, 1, 2};
//        hand.fingerBonesIndices[UnityXRFingerRing] = {0, 1, 2};
//        hand.fingerBonesIndices[UnityXRFingerPinky] = {0, 1, 2};
//        hand.rootBoneIndex = 22;
//        UnityXRBone {parentBoneIndex = 1, position={}, rotation={}};
//
//        input_DeviceState_SetBoneValue(state, , );
//
//      //  hand.fingerBonesIndices[UnityXRHandFinger]
////        UnityXRBone
////        hand.rootBoneIndex
////        hand.fingerBonesIndices[5]
////        UnityXRBone bone;
////        bone.position
////        bone.rotation
////        bone.parentBoneIndex
////
//        UnityXRHandFinger finger;
//        finger.
//        input_->DeviceState_
//        input_->DeviceState_SetHandValue(state, feature_index++,
//                                           head_pose_.position);
//        input_->DeviceState_SetBoneValue(state, feature_index++,
//                                           head_pose_.position);
//
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
