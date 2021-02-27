//
//  test_input.cpp
//  test-unity-plugin-input
//
//  Created by Yuchen on 2021/2/25.
//

#include <time.h>

#include <array>
#include <cmath>
#include <vector>

#include "IUnityInterface.h"
#include "IUnityXRInput.h"
#include "IUnityXRTrace.h"
#include "UnitySubsystemTypes.h"
#include "hand_tracking.mm"

#define HOLOKIT_INPUT_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrInputProvider]: " message "\n", \
               ##__VA_ARGS__)

namespace {

static int s_FrameCount = 0;

class HoloKitInputProvider {
public:
    HoloKitInputProvider(IUnityXRTrace* trace, IUnityXRInputInterface* input)
    : trace_(trace), input_(input) {
        // holokit_api_.reset(new holokit::unity::HoloKitApi());
    }
    
    IUnityXRInputInterface* GetInput() { return input_; }
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    static std::unique_ptr<HoloKitInputProvider>& GetInstance();
    
    /// Callback executed when a subsystem should initialize in preparation for becoming active.
    UnitySubsystemErrorCode Initialize(UnitySubsystemHandle handle, void* data) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< Lifecycle initialized");
        
        // Initialize XR Input Provider
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
            HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(),
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
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< Lifecycle started");
        
        // device connection happens here
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHme);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHand);
        
        //UnityXRVector3 boundary[4];
        //SetVector3(boundary[0], -1.f, 0.f, 1.f);
        //SetVector3(boundary[1], 1.f, 0.f, 1.f);
        //SetVector3(boundary[2], 1.f, 0.f, -1.f);
        //SetVector3(boundary[3], -1.f, 0.f, -1.f);
        //input_->InputSubsystem_SetTrackingBoundary(handle, boundary, 4);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< Lifecycle stopped");
        
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHme);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHand);
    }
    
    
    
    UnitySubsystemErrorCode Tick() {
        //HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "tick>>>>>>>>>>>>>>>>>>>>>>");
        
        std::array<float, 4> out_orientation;
        std::array<float, 3> out_position;
        
        head_pose_.position = UnityXRVector3 { 1.0f, 0.0f, 0.0f };
        head_pose_.rotation = UnityXRVector4 { 1.0f, 1.0f, 1.0f, 1.0f };
        
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    // this function should be called once for each connected device
    UnitySubsystemErrorCode FillDeviceDefinition(
        UnityXRInternalInputDeviceId device_id,
        UnityXRInputDeviceDefinition* definition) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< FillDeviceDefinition(): this device id is %d", device_id );
        
        switch (device_id) {
        
            case kDeviceIdHoloKitHme: {
                HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< connecting device HoloKitHme...");
                input_->DeviceDefinition_SetName(definition, "HoloKit HMD");
                input_->DeviceDefinition_SetCharacteristics(definition, kHmeCharacteristics);
                // features
                input_->DeviceDefinition_AddFeatureWithUsage(definition,
                    "Center Eye Position", kUnityXRInputFeatureTypeAxis3D,
                    kUnityXRInputFeatureUsageCenterEyePosition);
                input_->DeviceDefinition_AddFeatureWithUsage(definition,
                    "Center Eye Rotation", kUnityXRInputFeatureTypeRotation,
                    kUnityXRInputFeatureUsageCenterEyeRotation);
                // TODO: add more stuff
                
                break;
            }
            
            case kDeviceIdHoloKitHand: {
                HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< connecting device HoloKitHands...");
                input_->DeviceDefinition_SetName(definition, "HoloKit Hand");
                input_->DeviceDefinition_SetCharacteristics(definition, kHandCharacteristics);
                //input_->DeviceDefinition_SetManufacturer(definition, "Holo Interactive");
                
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
                
                break;
            }
            default:
                return kUnitySubsystemErrorCodeFailure;
        }
        
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    
    UnitySubsystemErrorCode UpdateDeviceState(
        UnityXRInternalInputDeviceId device_id, UnityXRInputDeviceState* state) {
        
        UnityXRVector3 translation;
        SetVector3(translation, 0.5, 0.0, 0.0);
        
        s_FrameCount++;
        UnityXRVector4 rotation = {0.0f, sin((float)s_FrameCount), 0.0f, 1.0f};
        
        // TODO: use update_type for low latency tracking
        
        UnityXRInputFeatureIndex feature_index = 0;
        
        switch (device_id) {
            case kDeviceIdHoloKitHme: {
                // update head pose position and rotation
                
                // for Center Eye Position
                input_->DeviceState_SetAxis3DValue(state, feature_index++, translation);
                // for Center Eye Rotation
                input_->DeviceState_SetRotationValue(state, feature_index++, rotation);
                break;
            }
            
            case kDeviceIdHoloKitHand: {
                break;
                // get the MediaPipe handtracking data
                ARSessionDelegateController *arSessionDelegateController = [ARSessionDelegateController sharedARSessionDelegateController];
                std::vector<std::vector<UnityXRVector3>> fingerBonePositions = arSessionDelegateController.landmarkPositions;
                
                // wrist
                input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = kUnityInvalidXRInputFeatureIndex, .position = fingerBonePositions[0][0], .rotation = {0, 0, 0, 1}});
                // thumb start
                input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = fingerBonePositions[0][1], .rotation = {0, 0, 0, 1}});
                // thumb 1
                input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = fingerBonePositions[0][2], .rotation = {0, 0, 0, 1}});
                // thumb 2
                input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = fingerBonePositions[0][3], .rotation = {0, 0, 0, 1}});
                // thumb end
                input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = fingerBonePositions[0][4], .rotation = {0, 0, 0, 1}});
                // index start
                input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = fingerBonePositions[0][5], .rotation = {0, 0, 0, 1}});
                // index 1
                input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = fingerBonePositions[0][6], .rotation = {0, 0, 0, 1}});
                // index 2
                input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = fingerBonePositions[0][7], .rotation = {0, 0, 0, 1}});
                // index end
                input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = fingerBonePositions[0][8], .rotation = {0, 0, 0, 1}});
                // middle start
                input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = fingerBonePositions[0][9], .rotation = {0, 0, 0, 1}});
                // middle 1
                input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = fingerBonePositions[0][10], .rotation = {0, 0, 0, 1}});
                // middle 2
                input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = fingerBonePositions[0][11], .rotation = {0, 0, 0, 1}});
                // middle end
                input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = fingerBonePositions[0][12], .rotation = {0, 0, 0, 1}});
                // ring start
                input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = fingerBonePositions[0][13], .rotation = {0, 0, 0, 1}});
                // ring 1
                input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = fingerBonePositions[0][14], .rotation = {0, 0, 0, 1}});
                // ring 2
                input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = fingerBonePositions[0][15], .rotation = {0, 0, 0, 1}});
                // ring end
                input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = fingerBonePositions[0][16], .rotation = {0, 0, 0, 1}});
                // pinky start
                input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = fingerBonePositions[0][17], .rotation = {0, 0, 0, 1}});
                // pinky 1
                input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = fingerBonePositions[0][18], .rotation = {0, 0, 0, 1}});
                // pinky 2
                input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = fingerBonePositions[0][19], .rotation = {0, 0, 0, 1}});
                // pinky end
                input_->DeviceState_SetBoneValue(state, 20, UnityXRBone {.parentBoneIndex = 19, .position = fingerBonePositions[0][20], .rotation = {0, 0, 0, 1}});
                feature_index = 21;
                
                UnityXRHand hand;
                hand.rootBoneIndex = 0;
                hand.fingerBonesIndices[UnityXRFingerThumb][0] = 1;
                hand.fingerBonesIndices[UnityXRFingerThumb][1] = 2;
                hand.fingerBonesIndices[UnityXRFingerThumb][2] = 3;
                hand.fingerBonesIndices[UnityXRFingerThumb][3] = 4;
                hand.fingerBonesIndices[UnityXRFingerThumb][4] = kUnityInvalidXRInputFeatureIndex;
                hand.fingerBonesIndices[UnityXRFingerIndex][0] = 5;
                hand.fingerBonesIndices[UnityXRFingerIndex][1] = 6;
                hand.fingerBonesIndices[UnityXRFingerIndex][2] = 7;
                hand.fingerBonesIndices[UnityXRFingerIndex][3] = 8;
                hand.fingerBonesIndices[UnityXRFingerIndex][4] = kUnityInvalidXRInputFeatureIndex;
                hand.fingerBonesIndices[UnityXRFingerMiddle][0] = 9;
                hand.fingerBonesIndices[UnityXRFingerMiddle][1] = 10;
                hand.fingerBonesIndices[UnityXRFingerMiddle][2] = 11;
                hand.fingerBonesIndices[UnityXRFingerMiddle][3] = 12;
                hand.fingerBonesIndices[UnityXRFingerMiddle][4] = kUnityInvalidXRInputFeatureIndex;
                hand.fingerBonesIndices[UnityXRFingerRing][0] = 13;
                hand.fingerBonesIndices[UnityXRFingerRing][1] = 14;
                hand.fingerBonesIndices[UnityXRFingerRing][2] = 15;
                hand.fingerBonesIndices[UnityXRFingerRing][3] = 16;
                hand.fingerBonesIndices[UnityXRFingerRing][4] = kUnityInvalidXRInputFeatureIndex;
                hand.fingerBonesIndices[UnityXRFingerPinky][0] = 17;
                hand.fingerBonesIndices[UnityXRFingerPinky][1] = 18;
                hand.fingerBonesIndices[UnityXRFingerPinky][2] = 19;
                hand.fingerBonesIndices[UnityXRFingerPinky][3] = 20;
                hand.fingerBonesIndices[UnityXRFingerPinky][4] = kUnityInvalidXRInputFeatureIndex;
                input_->DeviceState_SetHandValue(state, feature_index++, hand);
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
    static constexpr int kDeviceIdHoloKitHme = 0;
    static constexpr int kDeviceIdHoloKitHand = 13;
    
    static constexpr UnityXRInputDeviceCharacteristics kHmeCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
            kUnityXRInputDeviceCharacteristicsHeadMounted |
            kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    static constexpr UnityXRInputDeviceCharacteristics kHandCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
                                                       kUnityXRInputDeviceCharacteristicsRight |
                                                       kUnityXRInputDeviceCharacteristicsHandTracking |
                                                       kUnityXRInputDeviceCharacteristicsController |
                                                       kUnityXRInputDeviceCharacteristicsHeldInHand |
                                                       kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    // this combination does work
    //static constexpr UnityXRInputDeviceCharacteristics kHandCharacteristics =
    //    static_cast<UnityXRInputDeviceCharacteristics>(
    //                                                   kUnityXRInputDeviceCharacteristicsRight |
    //                                                   kUnityXRInputDeviceCharacteristicsHandTracking |
    //                                                   kUnityXRInputDeviceCharacteristicsTrackedDevice |
    //                                                   kUnityXRInputDeviceCharacteristicsController |
    //                                                   kUnityXRInputDeviceCharacteristicsHeldInHand);
    
    IUnityXRTrace* trace_ = nullptr;
    
    IUnityXRInputInterface* input_ = nullptr;
    
    UnityXRPose head_pose_;
    
    // define holokit_api_
    
    static std::unique_ptr<HoloKitInputProvider> holokit_input_provider_;
    
    static void SetVector3(UnityXRVector3& vector, float x, float y, float z)
    {
        vector.x = x;
        vector.y = y;
        vector.z = z;
    }
    
};

std::unique_ptr<HoloKitInputProvider> HoloKitInputProvider::holokit_input_provider_;

std::unique_ptr<HoloKitInputProvider>& HoloKitInputProvider::GetInstance() {
    return holokit_input_provider_;
}

} // namespace

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unity_interfaces) {
    
    auto* input = unity_interfaces->Get<IUnityXRInputInterface>();
    if (input == NULL) {
        // failed to load input subsystem
    }
    
    auto* trace = unity_interfaces->Get<IUnityXRTrace>();
    if (trace == NULL) {
        // failed to get trace
    }
    HOLOKIT_INPUT_XR_TRACE_LOG(trace, "<<<<<<<<<< Unity Plugin Load()");
    
    HoloKitInputProvider::GetInstance().reset(new HoloKitInputProvider(trace, input));
    
    UnityLifecycleProvider input_lifecycle_handler;
    input_lifecycle_handler.userData = NULL;
    input_lifecycle_handler.Initialize =
        [](UnitySubsystemHandle handle, void* data) -> UnitySubsystemErrorCode {
        return HoloKitInputProvider::GetInstance()->Initialize(handle, data);
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
    input->RegisterLifecycleProvider("XR SDK Input Sample", "input0", &input_lifecycle_handler);
    
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginUnload()
{
    
    HOLOKIT_INPUT_XR_TRACE_LOG(HoloKitInputProvider::GetInstance()->GetTrace(), "<<<<<<<<<< Unity Plugin Unload()");
    HoloKitInputProvider::GetInstance().reset();
}

 

