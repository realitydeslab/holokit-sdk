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
#include <iostream>

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
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandRight);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< Lifecycle stopped");
        
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHme);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandRight);
    }
    
    
    
    UnitySubsystemErrorCode Tick() {
        //HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "tick>>>>>>>>>>>>>>>>>>>>>>");
        
        //std::array<float, 4> out_orientation;
        //std::array<float, 3> out_position;
        
        head_pose_.position = UnityXRVector3 { 1.0f, 0.0f, 0.0f };
        head_pose_.rotation = UnityXRVector4 { 1.0f, 1.0f, 1.0f, 1.0f };
        
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    // this function should be called once for each connected device
    UnitySubsystemErrorCode FillDeviceDefinition(
        UnityXRInternalInputDeviceId device_id,
        UnityXRInputDeviceDefinition* definition) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< FillDeviceDefinition(): device id is %d", device_id );
        
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
            case kDeviceIdHoloKitHandLeft:
            case kDeviceIdHoloKitHandRight:
            {
                HOLOKIT_INPUT_XR_TRACE_LOG(holokit_input_provider_->GetTrace(), "<<<<<<<<<< connecting device HoloKitHandLeft...");
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
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "hand", kUnityXRInputFeatureTypeHand, kUnityXRInputFeatureUsageHandData);
                // is tracked?
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "isTracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
                
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "airTap", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
                input_->DeviceDefinition_AddFeatureWithUsage(definition, "bloom", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);

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
            case kDeviceIdHoloKitHandLeft: {
                // get the MediaPipe handtracking data
                if(arSessionDelegateController == nullptr) {
                    std::cout << "Fetch arSessionDelegateController" << std::endl;
                    arSessionDelegateController = [HoloKitARSession getSingletonInstance];
                }
                
                if([arSessionDelegateController.leftHandLandmarkPositions count] != 21){
                    //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                    std::cout << "not printing" << std::endl;
                    break;
                }
                
                //for(int i = 0;i<21;i++){
                //    NSLog(@"point world in SDK [%f, %f, %f]", arSessionDelegateController.leftHandLandmarkPositions[i].x, arSessionDelegateController.leftHandLandmarkPositions[i].y, arSessionDelegateController.leftHandLandmarkPositions[i].z);
                //}
                
                //std::cout << "updating left hand device" << std::endl;
                
                // wrist
                UnityXRVector3 position0 = { arSessionDelegateController.leftHandLandmarkPositions[0].x, arSessionDelegateController.leftHandLandmarkPositions[0].y, arSessionDelegateController.leftHandLandmarkPositions[0].z };
                input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = kUnityInvalidXRInputFeatureIndex, .position = position0, .rotation = {0, 0, 0, 1}});
                //NSLog(@"wrist in SDK [%f, %f, %f]", position0.x, position0.y, position0.z);
                // thumb start
                UnityXRVector3 position1 = { arSessionDelegateController.leftHandLandmarkPositions[1].x, arSessionDelegateController.leftHandLandmarkPositions[1].y, arSessionDelegateController.leftHandLandmarkPositions[1].z };
                input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = position1, .rotation = {0, 0, 0, 1}});
                // thumb 1
                UnityXRVector3 position2 = { arSessionDelegateController.leftHandLandmarkPositions[2].x, arSessionDelegateController.leftHandLandmarkPositions[2].y, arSessionDelegateController.leftHandLandmarkPositions[2].z };
                input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = position2, .rotation = {0, 0, 0, 1}});
                // thumb 2
                UnityXRVector3 position3 = { arSessionDelegateController.leftHandLandmarkPositions[3].x, arSessionDelegateController.leftHandLandmarkPositions[3].y, arSessionDelegateController.leftHandLandmarkPositions[3].z };
                input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = position3, .rotation = {0, 0, 0, 1}});
                // thumb end
                UnityXRVector3 position4 = { arSessionDelegateController.leftHandLandmarkPositions[4].x, arSessionDelegateController.leftHandLandmarkPositions[4].y, arSessionDelegateController.leftHandLandmarkPositions[4].z };
                input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = position4, .rotation = {0, 0, 0, 1}});
                // index start
                UnityXRVector3 position5 = { arSessionDelegateController.leftHandLandmarkPositions[5].x, arSessionDelegateController.leftHandLandmarkPositions[5].y, arSessionDelegateController.leftHandLandmarkPositions[5].z };
                input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = position5, .rotation = {0, 0, 0, 1}});
                // index 1
                UnityXRVector3 position6 = { arSessionDelegateController.leftHandLandmarkPositions[6].x, arSessionDelegateController.leftHandLandmarkPositions[6].y, arSessionDelegateController.leftHandLandmarkPositions[6].z };
                input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = position6, .rotation = {0, 0, 0, 1}});
                // index 2
                UnityXRVector3 position7 = { arSessionDelegateController.leftHandLandmarkPositions[7].x, arSessionDelegateController.leftHandLandmarkPositions[7].y, arSessionDelegateController.leftHandLandmarkPositions[7].z };
                input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = position7, .rotation = {0, 0, 0, 1}});
                // index end
                UnityXRVector3 position8 = { arSessionDelegateController.leftHandLandmarkPositions[8].x, arSessionDelegateController.leftHandLandmarkPositions[8].y, arSessionDelegateController.leftHandLandmarkPositions[8].z };
                input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = position8, .rotation = {0, 0, 0, 1}});
                // middle start
                UnityXRVector3 position9 = { arSessionDelegateController.leftHandLandmarkPositions[9].x, arSessionDelegateController.leftHandLandmarkPositions[9].y, arSessionDelegateController.leftHandLandmarkPositions[9].z };
                input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = position9, .rotation = {0, 0, 0, 1}});
                // middle 1
                UnityXRVector3 position10 = { arSessionDelegateController.leftHandLandmarkPositions[10].x, arSessionDelegateController.leftHandLandmarkPositions[10].y, arSessionDelegateController.leftHandLandmarkPositions[10].z };
                input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = position10, .rotation = {0, 0, 0, 1}});
                // middle 2
                UnityXRVector3 position11 = { arSessionDelegateController.leftHandLandmarkPositions[11].x, arSessionDelegateController.leftHandLandmarkPositions[11].y, arSessionDelegateController.leftHandLandmarkPositions[11].z };
                input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = position11, .rotation = {0, 0, 0, 1}});
                // middle end
                UnityXRVector3 position12 = { arSessionDelegateController.leftHandLandmarkPositions[12].x, arSessionDelegateController.leftHandLandmarkPositions[12].y, arSessionDelegateController.leftHandLandmarkPositions[12].z };
                input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = position12, .rotation = {0, 0, 0, 1}});
                // ring start
                UnityXRVector3 position13 = { arSessionDelegateController.leftHandLandmarkPositions[13].x, arSessionDelegateController.leftHandLandmarkPositions[13].y, arSessionDelegateController.leftHandLandmarkPositions[13].z };
                input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = position13, .rotation = {0, 0, 0, 1}});
                // ring 1
                UnityXRVector3 position14 = { arSessionDelegateController.leftHandLandmarkPositions[14].x, arSessionDelegateController.leftHandLandmarkPositions[14].y, arSessionDelegateController.leftHandLandmarkPositions[14].z };
                input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = position14, .rotation = {0, 0, 0, 1}});
                // ring 2
                UnityXRVector3 position15 = { arSessionDelegateController.leftHandLandmarkPositions[15].x, arSessionDelegateController.leftHandLandmarkPositions[15].y, arSessionDelegateController.leftHandLandmarkPositions[15].z };
                input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = position15, .rotation = {0, 0, 0, 1}});
                // ring end
                UnityXRVector3 position16 = { arSessionDelegateController.leftHandLandmarkPositions[16].x, arSessionDelegateController.leftHandLandmarkPositions[16].y, arSessionDelegateController.leftHandLandmarkPositions[16].z };
                input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = position16, .rotation = {0, 0, 0, 1}});
                // pinky start
                UnityXRVector3 position17 = { arSessionDelegateController.leftHandLandmarkPositions[17].x, arSessionDelegateController.leftHandLandmarkPositions[17].y, arSessionDelegateController.leftHandLandmarkPositions[17].z };
                input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = position17, .rotation = {0, 0, 0, 1}});
                // pinky 1
                UnityXRVector3 position18 = { arSessionDelegateController.leftHandLandmarkPositions[18].x, arSessionDelegateController.leftHandLandmarkPositions[18].y, arSessionDelegateController.leftHandLandmarkPositions[18].z };
                input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = position18, .rotation = {0, 0, 0, 1}});
                // pinky 2
                UnityXRVector3 position19 = { arSessionDelegateController.leftHandLandmarkPositions[19].x, arSessionDelegateController.leftHandLandmarkPositions[19].y, arSessionDelegateController.leftHandLandmarkPositions[19].z };
                input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = position19, .rotation = {0, 0, 0, 1}});
                // pinky end
                UnityXRVector3 position20 = { arSessionDelegateController.leftHandLandmarkPositions[20].x, arSessionDelegateController.leftHandLandmarkPositions[20].y, arSessionDelegateController.leftHandLandmarkPositions[20].z };
                input_->DeviceState_SetBoneValue(state, 20, UnityXRBone {.parentBoneIndex = 19, .position = position20, .rotation = {0, 0, 0, 1}});
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
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.isLeftHandTracked);
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, true);
                input_->DeviceState_SetBinaryValue(state, feature_index++, true);

                break;
            }
            case kDeviceIdHoloKitHandRight: {
                // get the MediaPipe handtracking data
                if(arSessionDelegateController == nullptr) {
                    std::cout << "Fetch arSessionDelegateController" << std::endl;
                    arSessionDelegateController = [HoloKitARSession getSingletonInstance];
                }
                
                if([arSessionDelegateController.rightHandLandmarkPositions count] != 21){
                    //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                    break;
                }
                //NSLog(@"the wrist position: [%f, %f, %f]", arSessionDelegateController.rightHandLandmarkPositions[0].x, arSessionDelegateController.rightHandLandmarkPositions[0].y, arSessionDelegateController.rightHandLandmarkPositions[0].z);
                
                // wrist
                UnityXRVector3 position = { arSessionDelegateController.rightHandLandmarkPositions[0].x, arSessionDelegateController.rightHandLandmarkPositions[0].y, arSessionDelegateController.rightHandLandmarkPositions[0].z };
                input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = kUnityInvalidXRInputFeatureIndex, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb start
                position = { arSessionDelegateController.rightHandLandmarkPositions[1].x, arSessionDelegateController.rightHandLandmarkPositions[1].y, arSessionDelegateController.rightHandLandmarkPositions[1].z };
                input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb 1
                position = { arSessionDelegateController.rightHandLandmarkPositions[2].x, arSessionDelegateController.rightHandLandmarkPositions[2].y, arSessionDelegateController.rightHandLandmarkPositions[2].z };
                input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb 2
                position = { arSessionDelegateController.rightHandLandmarkPositions[3].x, arSessionDelegateController.rightHandLandmarkPositions[3].y, arSessionDelegateController.rightHandLandmarkPositions[3].z };
                input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb end
                position = { arSessionDelegateController.rightHandLandmarkPositions[4].x, arSessionDelegateController.rightHandLandmarkPositions[4].y, arSessionDelegateController.rightHandLandmarkPositions[4].z };
                input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = position, .rotation = {0, 0, 0, 1}});
                // index start
                position = { arSessionDelegateController.rightHandLandmarkPositions[5].x, arSessionDelegateController.rightHandLandmarkPositions[5].y, arSessionDelegateController.rightHandLandmarkPositions[5].z };
                input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // index 1
                position = { arSessionDelegateController.rightHandLandmarkPositions[6].x, arSessionDelegateController.rightHandLandmarkPositions[6].y, arSessionDelegateController.rightHandLandmarkPositions[6].z };
                input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = position, .rotation = {0, 0, 0, 1}});
                // index 2
                position = { arSessionDelegateController.rightHandLandmarkPositions[7].x, arSessionDelegateController.rightHandLandmarkPositions[7].y, arSessionDelegateController.rightHandLandmarkPositions[7].z };
                input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = position, .rotation = {0, 0, 0, 1}});
                // index end
                position = { arSessionDelegateController.rightHandLandmarkPositions[8].x, arSessionDelegateController.rightHandLandmarkPositions[8].y, arSessionDelegateController.rightHandLandmarkPositions[8].z };
                input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = position, .rotation = {0, 0, 0, 1}});
                // middle start
                position = { arSessionDelegateController.rightHandLandmarkPositions[9].x, arSessionDelegateController.rightHandLandmarkPositions[9].y, arSessionDelegateController.rightHandLandmarkPositions[9].z };
                input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // middle 1
                position = { arSessionDelegateController.rightHandLandmarkPositions[10].x, arSessionDelegateController.rightHandLandmarkPositions[10].y, arSessionDelegateController.rightHandLandmarkPositions[10].z };
                input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = position, .rotation = {0, 0, 0, 1}});
                // middle 2
                position = { arSessionDelegateController.rightHandLandmarkPositions[11].x, arSessionDelegateController.rightHandLandmarkPositions[11].y, arSessionDelegateController.rightHandLandmarkPositions[11].z };
                input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = position, .rotation = {0, 0, 0, 1}});
                // middle end
                position = { arSessionDelegateController.rightHandLandmarkPositions[12].x, arSessionDelegateController.rightHandLandmarkPositions[12].y, arSessionDelegateController.rightHandLandmarkPositions[12].z };
                input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = position, .rotation = {0, 0, 0, 1}});
                // ring start
                position = { arSessionDelegateController.rightHandLandmarkPositions[13].x, arSessionDelegateController.rightHandLandmarkPositions[13].y, arSessionDelegateController.rightHandLandmarkPositions[13].z };
                input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // ring 1
                position = { arSessionDelegateController.rightHandLandmarkPositions[14].x, arSessionDelegateController.rightHandLandmarkPositions[14].y, arSessionDelegateController.rightHandLandmarkPositions[14].z };
                input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = position, .rotation = {0, 0, 0, 1}});
                // ring 2
                position = { arSessionDelegateController.rightHandLandmarkPositions[15].x, arSessionDelegateController.rightHandLandmarkPositions[15].y, arSessionDelegateController.rightHandLandmarkPositions[15].z };
                input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = position, .rotation = {0, 0, 0, 1}});
                // ring end
                position = { arSessionDelegateController.rightHandLandmarkPositions[16].x, arSessionDelegateController.rightHandLandmarkPositions[16].y, arSessionDelegateController.rightHandLandmarkPositions[16].z };
                input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky start
                position = { arSessionDelegateController.rightHandLandmarkPositions[17].x, arSessionDelegateController.rightHandLandmarkPositions[17].y, arSessionDelegateController.rightHandLandmarkPositions[17].z };
                input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky 1
                position = { arSessionDelegateController.rightHandLandmarkPositions[18].x, arSessionDelegateController.rightHandLandmarkPositions[18].y, arSessionDelegateController.rightHandLandmarkPositions[18].z };
                input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky 2
                position = { arSessionDelegateController.rightHandLandmarkPositions[19].x, arSessionDelegateController.rightHandLandmarkPositions[19].y, arSessionDelegateController.rightHandLandmarkPositions[19].z };
                input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky end
                position = { arSessionDelegateController.rightHandLandmarkPositions[20].x, arSessionDelegateController.rightHandLandmarkPositions[20].y, arSessionDelegateController.rightHandLandmarkPositions[20].z };
                input_->DeviceState_SetBoneValue(state, 20, UnityXRBone {.parentBoneIndex = 19, .position = position, .rotation = {0, 0, 0, 1}});
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
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, arSessionDelegateController.isRightHandTracked);
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
    static constexpr int kDeviceIdHoloKitHandLeft = 1;
    static constexpr int kDeviceIdHoloKitHandRight = 2;
    
    static constexpr UnityXRInputDeviceCharacteristics kHmeCharacteristics =
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
    
    HoloKitARSession *arSessionDelegateController;
    
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

 

