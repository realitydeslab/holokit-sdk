//
//  input.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <memory>
#include <iostream>

#include "IUnityInterface.h"
#include "IUnityXRTrace.h"
#include "IUnityXRInput.h"
#include "math_helpers.h"
#include "ar_session.mm"
#include "load.h"

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
        
        // Register ar session handler
        ar_session_handler_ = [ARSessionDelegateController sharedARSessionDelegateController];
        
        // TODO: Connect input devices
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHme);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceConnected(handle, kDeviceIdHoloKitHandRight);
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    void Stop(UnitySubsystemHandle handle) {
        HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Stop()", GetCurrentTime());
        
        // TODO: disconnect devices
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHme);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandLeft);
        input_->InputSubsystem_DeviceDisconnected(handle, kDeviceIdHoloKitHandRight);
    }
    
    UnitySubsystemErrorCode Tick() {
        //HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f Tick()", GetCurrentTime());
        
        return kUnitySubsystemErrorCodeSuccess;
    }
    
    // this function should be called once for each connected device
    UnitySubsystemErrorCode FillDeviceDefinition(
        UnityXRInternalInputDeviceId device_id,
        UnityXRInputDeviceDefinition* definition) {
        
        HOLOKIT_INPUT_XR_TRACE_LOG(input_provider_->GetTrace(), "<<<<<<<<<< FillDeviceDefinition(): device id is %d", device_id );
        
        switch (device_id) {
            case kDeviceIdHoloKitHme: {
                
                HOLOKIT_INPUT_XR_TRACE_LOG(input_provider_->GetTrace(), "<<<<<<<<<< connecting device HoloKitHme...");
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
                HOLOKIT_INPUT_XR_TRACE_LOG(input_provider_->GetTrace(), "<<<<<<<<<< connecting device HoloKitHandLeft...");
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
        
        // TODO: use update_type for low latency tracking
        
        UnityXRInputFeatureIndex feature_index = 0;
        
        switch (device_id) {
            case kDeviceIdHoloKitHme: {
                simd_float4x4 camera_transform = ar_session_handler_.session.currentFrame.camera.transform;
                //LogMatrix4x4(camera_transform);
                UnityXRVector3 position = UnityXRVector3 { camera_transform.columns[3].x, camera_transform.columns[3].y, -camera_transform.columns[3].z };
                //position = UnityXRVector3 { 0, 0, -5 };
                
                s_FrameCount++;
                UnityXRVector4 rotation = {0.0f, sin((float)s_FrameCount), 0.0f, 1.0f};
                
                simd_quatf quaternion = simd_quaternion(camera_transform);
                // update head pose position and rotation
                quaternion = simd_inverse(quaternion);
                rotation = UnityXRVector4 {quaternion.vector.x, quaternion.vector.y, quaternion.vector.z, quaternion.vector.w};
                //NSLog(@"position: %f, %f, %f", position.x, position.y, position.z);
                input_->DeviceState_SetAxis3DValue(state, feature_index++, position);
                input_->DeviceState_SetRotationValue(state, feature_index++, rotation);
                
                break;
            }
            case kDeviceIdHoloKitHandLeft: {
                // get the MediaPipe handtracking data
                if(ar_session_handler_ == nullptr) {
                    HOLOKIT_INPUT_XR_TRACE_LOG(trace_, "%f ar_session_handler is nullptr!", GetCurrentTime());
                }
                
                if([ar_session_handler_.leftHandLandmarkPositions count] != 21){
                    //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                    std::cout << "not printing" << std::endl;
                    break;
                }
                
                //for(int i = 0;i<21;i++){
                //    NSLog(@"point world in SDK [%f, %f, %f]", arSessionDelegateController.leftHandLandmarkPositions[i].x, arSessionDelegateController.leftHandLandmarkPositions[i].y, arSessionDelegateController.leftHandLandmarkPositions[i].z);
                //}
                
                //std::cout << "updating left hand device" << std::endl;
                
                // wrist
                UnityXRVector3 position0 = { ar_session_handler_.leftHandLandmarkPositions[0].x, ar_session_handler_.leftHandLandmarkPositions[0].y, ar_session_handler_.leftHandLandmarkPositions[0].z };
                input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = kUnityInvalidXRInputFeatureIndex, .position = position0, .rotation = {0, 0, 0, 1}});
                //NSLog(@"wrist in SDK [%f, %f, %f]", position0.x, position0.y, position0.z);
                // thumb start
                UnityXRVector3 position1 = { ar_session_handler_.leftHandLandmarkPositions[1].x, ar_session_handler_.leftHandLandmarkPositions[1].y, ar_session_handler_.leftHandLandmarkPositions[1].z };
                input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = position1, .rotation = {0, 0, 0, 1}});
                // thumb 1
                UnityXRVector3 position2 = { ar_session_handler_.leftHandLandmarkPositions[2].x, ar_session_handler_.leftHandLandmarkPositions[2].y, ar_session_handler_.leftHandLandmarkPositions[2].z };
                input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = position2, .rotation = {0, 0, 0, 1}});
                // thumb 2
                UnityXRVector3 position3 = { ar_session_handler_.leftHandLandmarkPositions[3].x, ar_session_handler_.leftHandLandmarkPositions[3].y, ar_session_handler_.leftHandLandmarkPositions[3].z };
                input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = position3, .rotation = {0, 0, 0, 1}});
                // thumb end
                UnityXRVector3 position4 = { ar_session_handler_.leftHandLandmarkPositions[4].x, ar_session_handler_.leftHandLandmarkPositions[4].y, ar_session_handler_.leftHandLandmarkPositions[4].z };
                input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = position4, .rotation = {0, 0, 0, 1}});
                // index start
                UnityXRVector3 position5 = { ar_session_handler_.leftHandLandmarkPositions[5].x, ar_session_handler_.leftHandLandmarkPositions[5].y, ar_session_handler_.leftHandLandmarkPositions[5].z };
                input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = position5, .rotation = {0, 0, 0, 1}});
                // index 1
                UnityXRVector3 position6 = { ar_session_handler_.leftHandLandmarkPositions[6].x, ar_session_handler_.leftHandLandmarkPositions[6].y, ar_session_handler_.leftHandLandmarkPositions[6].z };
                input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = position6, .rotation = {0, 0, 0, 1}});
                // index 2
                UnityXRVector3 position7 = { ar_session_handler_.leftHandLandmarkPositions[7].x, ar_session_handler_.leftHandLandmarkPositions[7].y, ar_session_handler_.leftHandLandmarkPositions[7].z };
                input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = position7, .rotation = {0, 0, 0, 1}});
                // index end
                UnityXRVector3 position8 = { ar_session_handler_.leftHandLandmarkPositions[8].x, ar_session_handler_.leftHandLandmarkPositions[8].y, ar_session_handler_.leftHandLandmarkPositions[8].z };
                input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = position8, .rotation = {0, 0, 0, 1}});
                // middle start
                UnityXRVector3 position9 = { ar_session_handler_.leftHandLandmarkPositions[9].x, ar_session_handler_.leftHandLandmarkPositions[9].y, ar_session_handler_.leftHandLandmarkPositions[9].z };
                input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = position9, .rotation = {0, 0, 0, 1}});
                // middle 1
                UnityXRVector3 position10 = { ar_session_handler_.leftHandLandmarkPositions[10].x, ar_session_handler_.leftHandLandmarkPositions[10].y, ar_session_handler_.leftHandLandmarkPositions[10].z };
                input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = position10, .rotation = {0, 0, 0, 1}});
                // middle 2
                UnityXRVector3 position11 = { ar_session_handler_.leftHandLandmarkPositions[11].x, ar_session_handler_.leftHandLandmarkPositions[11].y, ar_session_handler_.leftHandLandmarkPositions[11].z };
                input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = position11, .rotation = {0, 0, 0, 1}});
                // middle end
                UnityXRVector3 position12 = { ar_session_handler_.leftHandLandmarkPositions[12].x, ar_session_handler_.leftHandLandmarkPositions[12].y, ar_session_handler_.leftHandLandmarkPositions[12].z };
                input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = position12, .rotation = {0, 0, 0, 1}});
                // ring start
                UnityXRVector3 position13 = { ar_session_handler_.leftHandLandmarkPositions[13].x, ar_session_handler_.leftHandLandmarkPositions[13].y, ar_session_handler_.leftHandLandmarkPositions[13].z };
                input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = position13, .rotation = {0, 0, 0, 1}});
                // ring 1
                UnityXRVector3 position14 = { ar_session_handler_.leftHandLandmarkPositions[14].x, ar_session_handler_.leftHandLandmarkPositions[14].y, ar_session_handler_.leftHandLandmarkPositions[14].z };
                input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = position14, .rotation = {0, 0, 0, 1}});
                // ring 2
                UnityXRVector3 position15 = { ar_session_handler_.leftHandLandmarkPositions[15].x, ar_session_handler_.leftHandLandmarkPositions[15].y, ar_session_handler_.leftHandLandmarkPositions[15].z };
                input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = position15, .rotation = {0, 0, 0, 1}});
                // ring end
                UnityXRVector3 position16 = { ar_session_handler_.leftHandLandmarkPositions[16].x, ar_session_handler_.leftHandLandmarkPositions[16].y, ar_session_handler_.leftHandLandmarkPositions[16].z };
                input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = position16, .rotation = {0, 0, 0, 1}});
                // pinky start
                UnityXRVector3 position17 = { ar_session_handler_.leftHandLandmarkPositions[17].x, ar_session_handler_.leftHandLandmarkPositions[17].y, ar_session_handler_.leftHandLandmarkPositions[17].z };
                input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = position17, .rotation = {0, 0, 0, 1}});
                // pinky 1
                UnityXRVector3 position18 = { ar_session_handler_.leftHandLandmarkPositions[18].x, ar_session_handler_.leftHandLandmarkPositions[18].y, ar_session_handler_.leftHandLandmarkPositions[18].z };
                input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = position18, .rotation = {0, 0, 0, 1}});
                // pinky 2
                UnityXRVector3 position19 = { ar_session_handler_.leftHandLandmarkPositions[19].x, ar_session_handler_.leftHandLandmarkPositions[19].y, ar_session_handler_.leftHandLandmarkPositions[19].z };
                input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = position19, .rotation = {0, 0, 0, 1}});
                // pinky end
                UnityXRVector3 position20 = { ar_session_handler_.leftHandLandmarkPositions[20].x, ar_session_handler_.leftHandLandmarkPositions[20].y, ar_session_handler_.leftHandLandmarkPositions[20].z };
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
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, ar_session_handler_.isLeftHandTracked);
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, true);
                input_->DeviceState_SetBinaryValue(state, feature_index++, true);

                break;
            }
            case kDeviceIdHoloKitHandRight: {
                // get the MediaPipe handtracking data
                if(ar_session_handler_ == nullptr) {
                    std::cout << "Fetch arSessionDelegateController" << std::endl;
                    ar_session_handler_ = [ARSessionDelegateController sharedARSessionDelegateController];
                }
                
                if([ar_session_handler_.rightHandLandmarkPositions count] != 21){
                    //std::cout << "landmark zero... which means no landmark has been detected yet" << std::endl;
                    break;
                }
                //NSLog(@"the wrist position: [%f, %f, %f]", arSessionDelegateController.rightHandLandmarkPositions[0].x, arSessionDelegateController.rightHandLandmarkPositions[0].y, arSessionDelegateController.rightHandLandmarkPositions[0].z);
                
                // wrist
                UnityXRVector3 position = { ar_session_handler_.rightHandLandmarkPositions[0].x, ar_session_handler_.rightHandLandmarkPositions[0].y, ar_session_handler_.rightHandLandmarkPositions[0].z };
                input_->DeviceState_SetBoneValue(state, 0, UnityXRBone {.parentBoneIndex = kUnityInvalidXRInputFeatureIndex, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb start
                position = { ar_session_handler_.rightHandLandmarkPositions[1].x, ar_session_handler_.rightHandLandmarkPositions[1].y, ar_session_handler_.rightHandLandmarkPositions[1].z };
                input_->DeviceState_SetBoneValue(state, 1, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb 1
                position = { ar_session_handler_.rightHandLandmarkPositions[2].x, ar_session_handler_.rightHandLandmarkPositions[2].y, ar_session_handler_.rightHandLandmarkPositions[2].z };
                input_->DeviceState_SetBoneValue(state, 2, UnityXRBone {.parentBoneIndex = 1, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb 2
                position = { ar_session_handler_.rightHandLandmarkPositions[3].x, ar_session_handler_.rightHandLandmarkPositions[3].y, ar_session_handler_.rightHandLandmarkPositions[3].z };
                input_->DeviceState_SetBoneValue(state, 3, UnityXRBone {.parentBoneIndex = 2, .position = position, .rotation = {0, 0, 0, 1}});
                // thumb end
                position = { ar_session_handler_.rightHandLandmarkPositions[4].x, ar_session_handler_.rightHandLandmarkPositions[4].y, ar_session_handler_.rightHandLandmarkPositions[4].z };
                input_->DeviceState_SetBoneValue(state, 4, UnityXRBone {.parentBoneIndex = 3, .position = position, .rotation = {0, 0, 0, 1}});
                // index start
                position = { ar_session_handler_.rightHandLandmarkPositions[5].x, ar_session_handler_.rightHandLandmarkPositions[5].y, ar_session_handler_.rightHandLandmarkPositions[5].z };
                input_->DeviceState_SetBoneValue(state, 5, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // index 1
                position = { ar_session_handler_.rightHandLandmarkPositions[6].x, ar_session_handler_.rightHandLandmarkPositions[6].y, ar_session_handler_.rightHandLandmarkPositions[6].z };
                input_->DeviceState_SetBoneValue(state, 6, UnityXRBone {.parentBoneIndex = 5, .position = position, .rotation = {0, 0, 0, 1}});
                // index 2
                position = { ar_session_handler_.rightHandLandmarkPositions[7].x, ar_session_handler_.rightHandLandmarkPositions[7].y, ar_session_handler_.rightHandLandmarkPositions[7].z };
                input_->DeviceState_SetBoneValue(state, 7, UnityXRBone {.parentBoneIndex = 6, .position = position, .rotation = {0, 0, 0, 1}});
                // index end
                position = { ar_session_handler_.rightHandLandmarkPositions[8].x, ar_session_handler_.rightHandLandmarkPositions[8].y, ar_session_handler_.rightHandLandmarkPositions[8].z };
                input_->DeviceState_SetBoneValue(state, 8, UnityXRBone {.parentBoneIndex = 7, .position = position, .rotation = {0, 0, 0, 1}});
                // middle start
                position = { ar_session_handler_.rightHandLandmarkPositions[9].x, ar_session_handler_.rightHandLandmarkPositions[9].y, ar_session_handler_.rightHandLandmarkPositions[9].z };
                input_->DeviceState_SetBoneValue(state, 9, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // middle 1
                position = { ar_session_handler_.rightHandLandmarkPositions[10].x, ar_session_handler_.rightHandLandmarkPositions[10].y, ar_session_handler_.rightHandLandmarkPositions[10].z };
                input_->DeviceState_SetBoneValue(state, 10, UnityXRBone {.parentBoneIndex = 9, .position = position, .rotation = {0, 0, 0, 1}});
                // middle 2
                position = { ar_session_handler_.rightHandLandmarkPositions[11].x, ar_session_handler_.rightHandLandmarkPositions[11].y, ar_session_handler_.rightHandLandmarkPositions[11].z };
                input_->DeviceState_SetBoneValue(state, 11, UnityXRBone {.parentBoneIndex = 10, .position = position, .rotation = {0, 0, 0, 1}});
                // middle end
                position = { ar_session_handler_.rightHandLandmarkPositions[12].x, ar_session_handler_.rightHandLandmarkPositions[12].y, ar_session_handler_.rightHandLandmarkPositions[12].z };
                input_->DeviceState_SetBoneValue(state, 12, UnityXRBone {.parentBoneIndex = 11, .position = position, .rotation = {0, 0, 0, 1}});
                // ring start
                position = { ar_session_handler_.rightHandLandmarkPositions[13].x, ar_session_handler_.rightHandLandmarkPositions[13].y, ar_session_handler_.rightHandLandmarkPositions[13].z };
                input_->DeviceState_SetBoneValue(state, 13, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // ring 1
                position = { ar_session_handler_.rightHandLandmarkPositions[14].x, ar_session_handler_.rightHandLandmarkPositions[14].y, ar_session_handler_.rightHandLandmarkPositions[14].z };
                input_->DeviceState_SetBoneValue(state, 14, UnityXRBone {.parentBoneIndex = 13, .position = position, .rotation = {0, 0, 0, 1}});
                // ring 2
                position = { ar_session_handler_.rightHandLandmarkPositions[15].x, ar_session_handler_.rightHandLandmarkPositions[15].y, ar_session_handler_.rightHandLandmarkPositions[15].z };
                input_->DeviceState_SetBoneValue(state, 15, UnityXRBone {.parentBoneIndex = 14, .position = position, .rotation = {0, 0, 0, 1}});
                // ring end
                position = { ar_session_handler_.rightHandLandmarkPositions[16].x, ar_session_handler_.rightHandLandmarkPositions[16].y, ar_session_handler_.rightHandLandmarkPositions[16].z };
                input_->DeviceState_SetBoneValue(state, 16, UnityXRBone {.parentBoneIndex = 15, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky start
                position = { ar_session_handler_.rightHandLandmarkPositions[17].x, ar_session_handler_.rightHandLandmarkPositions[17].y, ar_session_handler_.rightHandLandmarkPositions[17].z };
                input_->DeviceState_SetBoneValue(state, 17, UnityXRBone {.parentBoneIndex = 0, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky 1
                position = { ar_session_handler_.rightHandLandmarkPositions[18].x, ar_session_handler_.rightHandLandmarkPositions[18].y, ar_session_handler_.rightHandLandmarkPositions[18].z };
                input_->DeviceState_SetBoneValue(state, 18, UnityXRBone {.parentBoneIndex = 17, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky 2
                position = { ar_session_handler_.rightHandLandmarkPositions[19].x, ar_session_handler_.rightHandLandmarkPositions[19].y, ar_session_handler_.rightHandLandmarkPositions[19].z };
                input_->DeviceState_SetBoneValue(state, 19, UnityXRBone {.parentBoneIndex = 18, .position = position, .rotation = {0, 0, 0, 1}});
                // pinky end
                position = { ar_session_handler_.rightHandLandmarkPositions[20].x, ar_session_handler_.rightHandLandmarkPositions[20].y, ar_session_handler_.rightHandLandmarkPositions[20].z };
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
                
                input_->DeviceState_SetBinaryValue(state, feature_index++, ar_session_handler_.isRightHandTracked);
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
    
    IUnityXRTrace* trace_ = nullptr;
    
    IUnityXRInputInterface* input_ = nullptr;
    
    static std::unique_ptr<HoloKitInputProvider> input_provider_;
    
    ARSessionDelegateController* ar_session_handler_;
};

std::unique_ptr<HoloKitInputProvider> HoloKitInputProvider::input_provider_;

std::unique_ptr<HoloKitInputProvider>& HoloKitInputProvider::GetInstance() {
    return input_provider_;
}
    
} //namespace


UnitySubsystemErrorCode LoadInput(IUnityInterfaces* xr_interface) {
    auto* input = xr_interface->Get<IUnityXRInputInterface>();
    if (input == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    
    auto* trace = xr_interface->Get<IUnityXRTrace>();
    if (trace == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    HoloKitInputProvider::GetInstance().reset(new HoloKitInputProvider(trace, input));
     HOLOKIT_INPUT_XR_TRACE_LOG(trace, "%f LoadInput()", GetCurrentTime());
    
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
