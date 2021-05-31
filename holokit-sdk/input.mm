//
//  input.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <memory>
#include <iostream>

#include "load.h"
#include "IUnityInterface.h"
#include "IUnityXRTrace.h"
#include "IUnityXRInput.h"
#include "math_helpers.h"
#include "holokit_api.h"

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_INPUT_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitInputProvider]: " message "\n", \
               ##__VA_ARGS__)

namespace{

static int s_FrameCount = 0;

class HoloKitInputProvider {
public:
    HoloKitInputProvider(IUnityXRTrace* trace, IUnityXRInputInterface* input)
        : trace_(trace), input_(input) { }
    
    IUnityXRInputInterface* GetInput() { return input_; }
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    void SetUnityInterfaces(IUnityInterfaces* xr_interfaces) { xr_interfaces_ = xr_interfaces; }
    
    static std::unique_ptr<HoloKitInputProvider>& GetInstance();
    
#pragma mark - Input Lifecycle Methods

    UnitySubsystemErrorCode Initialize(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Initialize()", GetCurrentTime());
        
        UnityXRInputProvider input_provider;
        input_provider.userData = nullptr;
        input_provider.Tick = [](UnitySubsystemHandle, void*, UnityXRInputUpdateType) {
            return GetInstance()->Tick();
        };
        input_provider.FillDeviceDefinition = [](UnitySubsystemHandle, void*, UnityXRInternalInputDeviceId device_id, UnityXRInputDeviceDefinition* definition) {
            return GetInstance()->FillDeviceDefinition(device_id, definition);
        };
        input_provider.UpdateDeviceState = [](UnitySubsystemHandle, void*, UnityXRInternalInputDeviceId device_id, UnityXRInputUpdateType, UnityXRInputDeviceState* state) {
            return GetInstance()->UpdateDeviceState(device_id, state);
        };
        input_provider.HandleEvent = [](UnitySubsystemHandle, void*, unsigned int, UnityXRInternalInputDeviceId, void*, unsigned int) {
            HOLOKIT_INPUT_XR_TRACE_LOG(input_provider_->GetTrace(),
                                           "No events to handle");
            return kUnitySubsystemErrorCodeSuccess;
        };
        input_provider.QueryTrackingOriginMode = [](UnitySubsystemHandle, void*, UnityXRInputTrackingOriginModeFlags* tracking_origin_mode) {
            return GetInstance()->QueryTrackingOriginMode(tracking_origin_mode);
        };
        input_provider.QuerySupportedTrackingOriginModes = [](UnitySubsystemHandle, void*, UnityXRInputTrackingOriginModeFlags* supported_tracking_origin_modes) {
            return GetInstance()->QuerySupportedTrackingOriginModes(supported_tracking_origin_modes);
        };
        input_provider.HandleSetTrackingOriginMode = [](UnitySubsystemHandle, void*, UnityXRInputTrackingOriginModeFlags tracking_origin_mode) {
            return GetInstance()->HandleSetTrackingOriginMode(tracking_origin_mode);
        };
        input_provider.HandleRecenter = nullptr;
        input_provider.HandleHapticImpulse = nullptr;
        input_provider.HandleHapticBuffer = nullptr;
        input_provider.QueryHapticCapabilities = nullptr;
        input_provider.HandleHapticStop = nullptr;
        GetInstance()->GetInput()->RegisterInputProvider(handle, &input_provider);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    UnitySubsystemErrorCode Start(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Start()", GetCurrentTime());
        
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHmd);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandRight);
        
        //ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Stop()", GetCurrentTime());
        
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHmd);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandRight);
    }
    
    UnitySubsystemErrorCode Tick() {
        /*
        HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Tick()", GetCurrentTime());
        NSLog(@"current frame count %d", s_FrameCount++);
        if(s_FrameCount == 1000) {
            NSLog(@"trying to load display subsystem");
            if(LoadDisplay(xr_interfaces_) == kUnitySubsystemErrorCodeSuccess) {
                NSLog(@"display loading succeeded");
            } else {
                NSLog(@"display loading failed");
            }
        }
         */
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    // this function should be called once for each connected device
    UnitySubsystemErrorCode FillDeviceDefinition(
        UnityXRInternalInputDeviceId device_id,
        UnityXRInputDeviceDefinition* definition) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(input_provider_->GetTrace(), "FillDeviceDefinition(): device id is %d", device_id );
        
        switch (device_id) {
            case kDeviceIdHoloKitHmd: {
                input_->DeviceDefinition_SetName(definition, "HoloKit HMD");
                input_->DeviceDefinition_SetCharacteristics(definition, kHmdCharacteristics);
                input_->DeviceDefinition_SetManufacturer(definition, "Holo Interactive");
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary,
                                                             kUnityXRInputFeatureUsageIsTracked);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates,
                                                             kUnityXRInputFeatureUsageTrackingState);
                input_->DeviceDefinition_AddFeatureWithUsage(definition,
                    "Center Eye Position", kUnityXRInputFeatureTypeAxis3D,
                    kUnityXRInputFeatureUsageCenterEyePosition);
                input_->DeviceDefinition_AddFeatureWithUsage(definition,
                    "Center Eye Rotation", kUnityXRInputFeatureTypeRotation,
                    kUnityXRInputFeatureUsageCenterEyeRotation);
                // TODO: add more stuff
                
                break;
            }
            case kDeviceIdHoloKitHandLeft:
            case kDeviceIdHoloKitHandRight:
            {
                if (device_id == kDeviceIdHoloKitHandLeft) {
                    input_->DeviceDefinition_SetName(definition, "HoloKit Left Hand");
                    input_->DeviceDefinition_SetCharacteristics(definition, kLeftHandCharacteristics);
                } else {
                    input_->DeviceDefinition_SetName(definition, "HoloKit Right Hand");
                    input_->DeviceDefinition_SetCharacteristics(definition, kRightHandCharacteristics);
                }
                input_->DeviceDefinition_SetManufacturer(definition, "Holo Interactive");
                // features defining 21 landmarks
                input_->DeviceDefinition_AddFeature(definition, "Wrist", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "ThumbStart", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Thumb1", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Thumb2", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "ThumbEnd", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "IndexStart", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Index1", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Index2", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "IndexEnd", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "MidStart", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Mid1", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Mid2", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "MidEnd", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "RingStart", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Ring1", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Ring2", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "RingEnd", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "PinkyStart", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Pinky1", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "Pinky2", kUnityXRInputFeatureTypeBone);
                input_->DeviceDefinition_AddFeature(definition, "PinkyEnd", kUnityXRInputFeatureTypeBone);
                // for XR hand
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Hand", kUnityXRInputFeatureTypeHand, kUnityXRInputFeatureUsageHandData);
                // is tracked?
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates,
                                                             kUnityXRInputFeatureUsageTrackingState);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Primary Button", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
                
                // Finger Status
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Thumb Finger Open", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageLegacyButton0);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Index Finger Open", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageLegacyButton1);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Mid Finger Open", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageLegacyButton2);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Ring Finger Open", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageLegacyButton3);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Pinky Finger Open", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageLegacyButton4);
                
                // Gesture Status
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Spider Man", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "One", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Two", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Three", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Four", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Five", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Fist", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Thumb Up", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Okay", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
                
                // Movement
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Air Tap", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
//                input_->DeviceDefinition_AddFeatureWithUsage(definition, "Bloom", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);

                break;
            }
            default:
                return kUnitySubsystemErrorCodeFailure;
        }
        return kUnitySubsystemErrorCodeSuccess;
    }
    
#pragma mark - UpdateDeviceState()
    
    UnitySubsystemErrorCode UpdateDeviceState(
        UnityXRInternalInputDeviceId device_id, UnityXRInputDeviceState* state) {
        
        // TODO: use update_type for low latency tracking
        
        static const UnityXRInputFeatureIndex parent_bone_index[] = {kUnityInvalidXRInputFeatureIndex, 0, 1, 2, 3, 0, 5, 6, 7, 0, 9, 10, 11, 0, 13, 14, 15, 0, 17, 18, 19};
        
        static const UnityXRHand hand = {0, {
            {1, 2, 3, 4, kUnityInvalidXRInputFeatureIndex},
            {5, 6, 7, 8, kUnityInvalidXRInputFeatureIndex},
            {9, 10, 11, 12, kUnityInvalidXRInputFeatureIndex},
            {13, 14, 15, 16, kUnityInvalidXRInputFeatureIndex},
            {17, 18, 19, 20, kUnityInvalidXRInputFeatureIndex}
        }};
        
        UnityXRInputFeatureIndex feature_index = 0;
        
        switch (device_id) {
            case kDeviceIdHoloKitHmd: {
                simd_float4x4 camera_transform = holokit::HoloKitApi::GetInstance()->GetCurrentCameraTransform();
                simd_float3 camera_position = simd_make_float3(camera_transform.columns[3].x, camera_transform.columns[3].y, camera_transform.columns[3].z);
                //simd_float3 offset = holokit::HoloKitApi::GetInstance()->GetCameraToCenterEyeOffset();
                simd_float3 center_eye_position = camera_position;
                //simd_float3 center_eye_position = camera_position + offset;
                UnityXRVector3 position = UnityXRVector3 { center_eye_position.x, center_eye_position.y, -center_eye_position.z };
                //UnityXRVector3 position = UnityXRVector3 { 0, 0, 0 };
                
                simd_quatf quaternion = simd_quaternion(camera_transform);
                UnityXRVector4 rotation = UnityXRVector4 { -quaternion.vector.x, -quaternion.vector.y, quaternion.vector.z, quaternion.vector.w };
                //UnityXRVector4 rotation = UnityXRVector4 { 0, 0, 0, 1 };
                //Is Tracked
                input_->DeviceState_SetBinaryValue(state, feature_index++, true);
                //Track State
                input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStatePosition | kUnityXRInputTrackingStateRotation);
                //Center Eye Position
                input_->DeviceState_SetAxis3DValue(state, feature_index++, position);
                //Center Eye Rotation
                input_->DeviceState_SetRotationValue(state, feature_index++, rotation);
                
                break;
            }
            case kDeviceIdHoloKitHandLeft: {
                ARSessionDelegateController* arSessionDelegateController = [ARSessionDelegateController sharedARSessionDelegateController];

                if ([arSessionDelegateController.leftHandLandmarkPositions count] != 21){
                   //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                   break;
                }

                for (int i = 0; i < 21; i++) {
                  UnityXRVector3 position = {arSessionDelegateController.leftHandLandmarkPositions[i].x, arSessionDelegateController.leftHandLandmarkPositions[i].y, arSessionDelegateController.leftHandLandmarkPositions[i].z};
                  input_->DeviceState_SetBoneValue(state, feature_index++, UnityXRBone {.parentBoneIndex = parent_bone_index[i], .position = position, .rotation = {0, 0, 0, 1}});
                }

                input_->DeviceState_SetHandValue(state, feature_index++, hand);

                // Is Tracked
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.isLeftHandTracked);
                input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStateAll);
                // Primary button
                //NSLog(@"hahaha: %d", arSessionDelegateController.primaryButtonValues[0]);
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.primaryButtonLeft);
                
                bool isThumbFingerOpen = false;
                bool isIndexFingerOpen = true;
                bool isMidFingerOpen = false;
                bool isRingFingerOpen = true;
                bool isPinkyFingerOpen = false;

                input_->DeviceState_SetBinaryValue(state, feature_index++, isThumbFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isIndexFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isMidFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isRingFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isPinkyFingerOpen);

                break;
            }
            case kDeviceIdHoloKitHandRight: {
                ARSessionDelegateController* arSessionDelegateController = [ARSessionDelegateController sharedARSessionDelegateController];

                if ([arSessionDelegateController.rightHandLandmarkPositions count] != 21){
                   //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                   break;
                }

                for (int i = 0; i < 21; i++) {
                  UnityXRVector3 position = {arSessionDelegateController.rightHandLandmarkPositions[i].x, arSessionDelegateController.rightHandLandmarkPositions[i].y, arSessionDelegateController.rightHandLandmarkPositions[i].z};
                  input_->DeviceState_SetBoneValue(state, feature_index++, UnityXRBone {.parentBoneIndex = parent_bone_index[i], .position = position, .rotation = {0, 0, 0, 1}});
                }


                input_->DeviceState_SetHandValue(state, feature_index++, hand);

                //Is Tracked
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.isRightHandTracked);
                input_->DeviceState_SetDiscreteStateValue(state, feature_index++, kUnityXRInputTrackingStateAll);
                // Primary button
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.primaryButtonRight);
                
                bool isThumbFingerOpen = false;
                bool isIndexFingerOpen = false;
                bool isMidFingerOpen = false;
                bool isRingFingerOpen = false;
                bool isPinkyFingerOpen = false;

                input_->DeviceState_SetBinaryValue(state, feature_index++, isThumbFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isIndexFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isMidFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isRingFingerOpen);
                input_->DeviceState_SetBinaryValue(state, feature_index++, isPinkyFingerOpen);

                break;
            }
            default:
                return kUnitySubsystemErrorCodeFailure;
        }
        return kUnitySubsystemErrorCodeSuccess;
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
    static constexpr int kDeviceIdHoloKitHmd = 0;
    static constexpr int kDeviceIdHoloKitHandLeft = 1;
    static constexpr int kDeviceIdHoloKitHandRight = 2;
    
    static constexpr UnityXRInputDeviceCharacteristics kHmdCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
            kUnityXRInputDeviceCharacteristicsHeadMounted |
            kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    static constexpr UnityXRInputDeviceCharacteristics kLeftHandCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
                                                       kUnityXRInputDeviceCharacteristicsLeft |
                                                       kUnityXRInputDeviceCharacteristicsHandTracking |
                                                       kUnityXRInputDeviceCharacteristicsController |
                                                       kUnityXRInputDeviceCharacteristicsHeldInHand |
                                                       kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    static constexpr UnityXRInputDeviceCharacteristics kRightHandCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
                                                       kUnityXRInputDeviceCharacteristicsRight |
                                                       kUnityXRInputDeviceCharacteristicsHandTracking |
                                                       kUnityXRInputDeviceCharacteristicsController |
                                                       kUnityXRInputDeviceCharacteristicsHeldInHand |
                                                       kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    IUnityXRTrace* trace_ = nullptr;
    
    IUnityXRInputInterface* input_ = nullptr;
    
    static std::unique_ptr<HoloKitInputProvider> input_provider_;
    
    ARSessionDelegateController* ar_session_handler;
    
    IUnityInterfaces* xr_interfaces_;
};

std::unique_ptr<HoloKitInputProvider> HoloKitInputProvider::input_provider_;

std::unique_ptr<HoloKitInputProvider>& HoloKitInputProvider::GetInstance() {
    return input_provider_;
}
    
} //namespace


UnitySubsystemErrorCode LoadInput(IUnityInterfaces* xr_interfaces) {
    auto* input = xr_interfaces->Get<IUnityXRInputInterface>();
    if (input == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    
    auto* trace = xr_interfaces->Get<IUnityXRTrace>();
    if (trace == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    HOLOKIT_INPUT_XR_TRACE_LOG(trace, "%f LoadInput()", GetCurrentTime());
    
    HoloKitInputProvider::GetInstance().reset(new HoloKitInputProvider(trace, input));

    HoloKitInputProvider::GetInstance()->SetUnityInterfaces(xr_interfaces);
    
    UnityLifecycleProvider input_lifecycle_handler;
    input_lifecycle_handler.userData = NULL;
    input_lifecycle_handler.Initialize = [](UnitySubsystemHandle handle, void*) -> UnitySubsystemErrorCode {
        return HoloKitInputProvider::GetInstance()->Initialize(handle);
    };
    input_lifecycle_handler.Start = [](UnitySubsystemHandle handle, void*) {
        return HoloKitInputProvider::GetInstance()->Start(handle);
    };
    input_lifecycle_handler.Stop = [](UnitySubsystemHandle handle, void*) {
        return HoloKitInputProvider::GetInstance()->Stop(handle);
    };
    input_lifecycle_handler.Shutdown = [](UnitySubsystemHandle, void*) {
        HOLOKIT_INPUT_XR_TRACE_LOG(
                HoloKitInputProvider::GetInstance()->GetTrace(),
                "Lifecycle finished");
    };
    return HoloKitInputProvider::GetInstance()->GetInput()->RegisterLifecycleProvider("HoloKit XR Plugin", "HoloKit Input", &input_lifecycle_handler);
}

void UnloadInput() { HoloKitInputProvider::GetInstance().reset(); }
