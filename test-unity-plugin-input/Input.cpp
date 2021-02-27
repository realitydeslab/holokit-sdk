//
//  Input.cpp
//  test-unity-plugin-input
//
//  Created by Yuchen on 2021/2/25.
//

#include "XR/IUnityXRInput.h"
#include "XR/IUnityXRTrace.h"

#include "MathHelpers.h"

static unsigned int kControllerConnectedFrameCount = 5;

/// Input Feature Effect Constants
static float kHMDRotationSpeed = -0.005f;
static float kMaxHMDRotationAngle = 2.0f;
static float kCenterEyeForwardOffset = 0.01f;
static float kRotationSpeed = 0.01f;
static float kAxisMovementSpeed = 0.01f;
static float kAxisUpdateIncrement = 0.005f;
static float kAxisMax = 1.0f;
static float kControllerMovementSpeed = 0.001f;
static float kControllerMaxDistance = 1.f;
static int kButtonLoopInterval = 275;
static int kMultiMappedButtonInterval = 100;
static int kControllerSwapInterval = 1000;

// clang-format off
static UnityXRInputDeviceCharacteristics hmdCharacteristics = (UnityXRInputDeviceCharacteristics)
                               (kUnityXRInputDeviceCharacteristicsHeadMounted
                               | kUnityXRInputDeviceCharacteristicsTrackedDevice);
static UnityXRInputDeviceCharacteristics leftControllerCharacteristics = (UnityXRInputDeviceCharacteristics)
                               (kUnityXRInputDeviceCharacteristicsLeft
                               | kUnityXRInputDeviceCharacteristicsTrackedDevice
                               | kUnityXRInputDeviceCharacteristicsController
                               | kUnityXRInputDeviceCharacteristicsHeldInHand);
static UnityXRInputDeviceCharacteristics rightControllerCharacteristics = (UnityXRInputDeviceCharacteristics)
                               (kUnityXRInputDeviceCharacteristicsRight
                               | kUnityXRInputDeviceCharacteristicsTrackedDevice
                               | kUnityXRInputDeviceCharacteristicsController
                               | kUnityXRInputDeviceCharacteristicsHeldInHand);

static UnityXRInputDeviceCharacteristics handCharacteristics = (UnityXRInputDeviceCharacteristics)
                                (kUnityXRInputDeviceCharacteristicsController
                                 | kUnityXRInputDeviceCharacteristicsHeldInHand);


// clang-format on

static IUnityInterfaces* s_UnityInterfaces;
static IUnityXRInputInterface* s_XrInput = nullptr;
static IUnityXRTrace* s_XrTrace = nullptr;

// Simple HMD-like device to simulate incoming input data
typedef struct MockHMD
{
    void Reset()
    {
        updateCount = 0;

        isTracked = true;
        trackingState = kUnityXRInputTrackingStatePosition | kUnityXRInputTrackingStateRotation;
        position.x = position.y = position.z = 0.0F;
        centerEyePosition.x = centerEyePosition.y = 0.0F;
        centerEyePosition.z = position.z + kCenterEyeForwardOffset;

        rotation.x = rotation.y = rotation.z = 0.0F;
    }

    void Update()
    {
        updateCount++;

        rotation.y = sin(((float)updateCount) * kHMDRotationSpeed) * kMaxHMDRotationAngle * 0.1;
        
        //position.x += 0.1;
    }

    void Recenter()
    {
        updateCount = 0;
        rotation.y = 0.0F;
    }

    bool isTracked;
    unsigned int trackingState;
    UnityXRVector3 position;
    UnityXRVector3 rotation;
    UnityXRVector3 centerEyePosition;

    // Bookkeeping for fake input values
    unsigned int updateCount;
} MockHMD;

// Simple Controller to simulate incoming tracking, buttons, and axes
typedef struct MockController
{
    void Reset()
    {
        updateCount = 0;
        direction = 1.0F;

        isTracked = true;
        trackingState = kUnityXRInputTrackingStatePosition | kUnityXRInputTrackingStateRotation;
        position.x = position.y = position.z = 0.0F;
        rotation.x = rotation.y = rotation.z = 0.0F;

        button = false;
        axis = 0.0f;
        axis2D.x = axis2D.y = 0.0F;
        unmappedButton = true;
        multiMappedButton = false;
    }

    void Update()
    {
        updateCount++;

        position.x += direction * kControllerMovementSpeed;
        if (fabs(position.x) > kControllerMaxDistance)
            position.x *= -1.0F;

        rotation.z -= kRotationSpeed;

        if ((updateCount % kButtonLoopInterval) == 0)
            button = !button;

        axis += kAxisUpdateIncrement;
        if (axis > kAxisMax)
            axis -= kAxisMax;
        axis2D.x = sin(((float)updateCount) * kAxisMovementSpeed);
        axis2D.y = cos(((float)updateCount) * kAxisMovementSpeed);

        if ((updateCount % kMultiMappedButtonInterval) == 0)
            multiMappedButton = !multiMappedButton;
    }

    void Recenter()
    {
        position.x = 0.0F;
        rotation.z = 0.0F;
    }

    bool isTracked;
    unsigned int trackingState;
    UnityXRVector3 position;
    UnityXRVector3 rotation;

    bool button;
    float axis;
    UnityXRVector2 axis2D;
    bool unmappedButton;
    bool multiMappedButton;

    // Bookkeeping for fake input values
    float direction;
    unsigned int updateCount;
} MockController;

typedef struct InputProviderData
{
    void Reset()
    {
        frameCount = 0;

        controllerCharacteristics = leftControllerCharacteristics;
        hmd.Reset();
        controller.Reset();
    }

    unsigned int frameCount;

    UnityXRInputDeviceCharacteristics controllerCharacteristics;
    MockHMD hmd;
    MockController controller;
} InputProviderData;

static InputProviderData s_ProviderData;

enum SampleDeviceIds
{
    kDeviceId_HMD = 0,
    kDeviceId_Controller
};

static UnitySubsystemErrorCode Tick(UnitySubsystemHandle handle, void* userData, UnityXRInputUpdateType updateType)
{
    if (updateType == kUnityXRInputUpdateTypeDynamic)
        s_ProviderData.frameCount++;

    
    // You can connect a controller anytime you want
    if (s_ProviderData.frameCount == kControllerConnectedFrameCount)
        s_XrInput->InputSubsystem_DeviceConnected(handle, kDeviceId_Controller);

    if ((s_ProviderData.frameCount > kControllerConnectedFrameCount) && (s_ProviderData.frameCount % kControllerSwapInterval) == 0)
    {
        s_XrInput->InputSubsystem_DeviceDisconnected(handle, kDeviceId_Controller);
        s_XrInput->InputSubsystem_DeviceConnected(handle, kDeviceId_Controller);
        s_ProviderData.controllerCharacteristics = (s_ProviderData.controllerCharacteristics == leftControllerCharacteristics) ? rightControllerCharacteristics : leftControllerCharacteristics;
    }
     

    s_ProviderData.hmd.Update();
    s_ProviderData.controller.Update();

    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode FillDeviceDefinition(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId, UnityXRInputDeviceDefinition* definition)
{
    //These definitions should reflect the devices you intend to use.
    switch (deviceId)
    {
    case kDeviceId_HMD:
    {
        s_XrInput->DeviceDefinition_SetName(definition, "Sample HMD");
        s_XrInput->DeviceDefinition_SetCharacteristics(definition, hmdCharacteristics);

        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates, kUnityXRInputFeatureUsageTrackingState);

        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Device Position", kUnityXRInputFeatureTypeAxis3D, kUnityXRInputFeatureUsageDevicePosition);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Device Rotation", kUnityXRInputFeatureTypeRotation, kUnityXRInputFeatureUsageDeviceRotation);

        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Center Eye Position", kUnityXRInputFeatureTypeAxis3D, kUnityXRInputFeatureUsageCenterEyePosition);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Center Eye Rotation", kUnityXRInputFeatureTypeRotation, kUnityXRInputFeatureUsageCenterEyeRotation);
    }
    break;
            
    case kDeviceId_Controller:
    {
        s_XrInput->DeviceDefinition_SetName(definition, "Sample Controller Aris");
        s_XrInput->DeviceDefinition_SetCharacteristics(definition, s_ProviderData.controllerCharacteristics);
        //s_XrInput->DeviceDefinition_SetCharacteristics(definition, handCharacteristics);

        
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Is Tracked", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsageIsTracked);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Tracking State", kUnityXRInputFeatureTypeDiscreteStates, kUnityXRInputFeatureUsageTrackingState);

        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Device Position", kUnityXRInputFeatureTypeAxis3D, kUnityXRInputFeatureUsageDevicePosition);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Device Rotation", kUnityXRInputFeatureTypeRotation, kUnityXRInputFeatureUsageDeviceRotation);

        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Sample Button", kUnityXRInputFeatureTypeBinary, kUnityXRInputFeatureUsagePrimaryButton);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Sample Axis", kUnityXRInputFeatureTypeAxis1D, kUnityXRInputFeatureUsageLegacyAxis3);
        s_XrInput->DeviceDefinition_AddFeatureWithUsage(definition, "Sample 2D Axis", kUnityXRInputFeatureTypeAxis2D, kUnityXRInputFeatureUsagePrimary2DAxis);

        
        s_XrInput->DeviceDefinition_AddFeature(definition, "Unmapped Button", kUnityXRInputFeatureTypeBinary);

        UnityXRInputFeatureIndex featureIndex = s_XrInput->DeviceDefinition_AddFeature(definition, "Multi-Usage Button", kUnityXRInputFeatureTypeBinary);
        s_XrInput->DeviceDefinition_AddUsageAtIndex(definition, featureIndex, kUnityXRInputFeatureUsageSecondaryButton);
        s_XrInput->DeviceDefinition_AddUsageAtIndex(definition, featureIndex, kUnityXRInputFeatureUsageLegacyButton11);
        s_XrInput->DeviceDefinition_AddUsageAtIndex(definition, featureIndex, kUnityXRInputFeatureUsageLegacyButton12);
         
    }
             
    break;
    default:
        return kUnitySubsystemErrorCodeFailure;
    }
    return kUnitySubsystemErrorCodeSuccess;
}

static void SetVector3(UnityXRVector3& vector, float x, float y, float z);

static UnitySubsystemErrorCode UpdateDeviceState(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId, UnityXRInputUpdateType updateType, UnityXRInputDeviceState* state)
{
    XR_TRACE_LOG(s_XrTrace, "device state updated>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    
    UnityXRInputFeatureIndex featureIndex = 0;

    // Feature values should either be stored as indices when creating the device definitions, or you can also follow this incrementing pattern
    // and use the *exact* same feature order as declared in the definition.
    switch (deviceId)
    {
    case kDeviceId_HMD:
    {
        MockHMD* hmd = &s_ProviderData.hmd;
        s_XrInput->DeviceState_SetBinaryValue(state, featureIndex++, hmd->isTracked);
        s_XrInput->DeviceState_SetDiscreteStateValue(state, featureIndex++, hmd->trackingState);
        s_XrInput->DeviceState_SetAxis3DValue(state, featureIndex++, hmd->position);
        //s_XrInput->DeviceState_SetAxis3DValue(state, featureIndex++, translate);
        
        UnityXRVector4 rotationQuaternion = MathHelpers::EulerToQuaternion(hmd->rotation);
        //UnityXRVector4 rotationQuaternion = MathHelpers::EulerToQuaternion(rotate);
        s_XrInput->DeviceState_SetRotationValue(state, featureIndex++, rotationQuaternion);

        s_XrInput->DeviceState_SetAxis3DValue(state, featureIndex++, hmd->centerEyePosition);
        //s_XrInput->DeviceState_SetAxis3DValue(state, featureIndex++, translate);
        s_XrInput->DeviceState_SetRotationValue(state, featureIndex++, rotationQuaternion);
    }
    break;
    case kDeviceId_Controller:
    {
        
        MockController* controller = &s_ProviderData.controller;
        s_XrInput->DeviceState_SetBinaryValue(state, featureIndex++, controller->isTracked);
        s_XrInput->DeviceState_SetDiscreteStateValue(state, featureIndex++, controller->trackingState);
        s_XrInput->DeviceState_SetAxis3DValue(state, featureIndex++, controller->position);

        UnityXRVector4 rotationQuaternion = MathHelpers::EulerToQuaternion(controller->rotation);
        s_XrInput->DeviceState_SetRotationValue(state, featureIndex++, rotationQuaternion);

        s_XrInput->DeviceState_SetBinaryValue(state, featureIndex++, controller->button);
        s_XrInput->DeviceState_SetAxis1DValue(state, featureIndex++, controller->axis);
        s_XrInput->DeviceState_SetAxis2DValue(state, featureIndex++, controller->axis2D);
        s_XrInput->DeviceState_SetBinaryValue(state, featureIndex++, controller->unmappedButton);
        s_XrInput->DeviceState_SetBinaryValue(state, featureIndex++, controller->multiMappedButton);
         
    }
    break;
    default:
        return kUnitySubsystemErrorCodeFailure;
    }
    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode HandleEvent(UnitySubsystemHandle handle, void* userData, unsigned int eventType, UnityXRInternalInputDeviceId deviceId, void* buffer, unsigned int size)
{
    // This is used to handle events from other systems (such as the Input System), or private events custom to this provider.
    // The Provider should only operate on events, where it recognizes the eventType.
    // If you do not recognize the format of the event, return kUnitySubsystemErrorCodeFailure.
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Handle Event received with eventType[%u], DeviceId[%llu], Buffer Size[%u].", eventType, deviceId, size);

    return kUnitySubsystemErrorCodeFailure;
}

static UnitySubsystemErrorCode HandleRecenter(UnitySubsystemHandle handle, void* userData)
{
    // When handling this event, the provider must set the tracking origin for all devices to the current position
    // and yaw of a consistent input device, usually representing the display or a primary sensor.

    //For example: a virtual reality system’s reference device would be the head mounted display.
    // A phone-based augmented reality system’s reference device would be the phone itself.

    // Return kUnitySubsystemErrorCodeFailure if the SDK was unable to recenter.
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Handle Recenter received.");

    s_ProviderData.hmd.Recenter();
    s_ProviderData.controller.Recenter();

    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode HandleHapticImpulse(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId, int channel, float amplitude, float duration)
{
    // Handles a request from Unity to trigger a haptic impulse on a specific device.
    // If the impulse could not be triggered for any reason return kUnitySubsystemErrorCodeFailure.
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Handle Haptic Impulse received with DeviceId[%llu], Channel[%i], Amplitude[%f], Duration[%f].", deviceId, channel, amplitude, duration);

    return kUnitySubsystemErrorCodeFailure;
}

static UnitySubsystemErrorCode HandleHapticBuffer(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId, int channel, unsigned int bufferSize, const unsigned char* const buffer)
{
    // Handles a request from Unity to trigger a buffered haptic effect on a specific device.
    // If the effect could not be triggered for any reason return kUnitySubsystemErrorCodeFailure.
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Handle Haptic Buffer received with DeviceId[%llu], Channel[%i], Buffer Size[%i].", deviceId, channel, bufferSize);

    return kUnitySubsystemErrorCodeFailure;
}

static UnitySubsystemErrorCode QueryHapticCapabilities(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId, UnityXRHapticCapabilities* capabilities)
{
    // This event expects the UnityXRHapticCapbilities structure passed in to be filled.
    // This structure informs Unity of the haptic capabilities available for a specific DeviceId.
    // Return kUnitySubsystemErrorCodeSuccess if the structure was filled in, kUnitySubsystemErrorCodeFailure otherwise.
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Query Haptic Capabilities received with DeviceId[%llu].", deviceId);

    capabilities->numChannels = 0;
    capabilities->supportsImpulse = false;
    capabilities->supportsBuffer = false;
    capabilities->bufferFrequencyHz = 0;
    capabilities->bufferMaxSize = 0;
    capabilities->bufferOptimalSize = 0;

    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode HandleHapticStop(UnitySubsystemHandle handle, void* userData, UnityXRInternalInputDeviceId deviceId)
{
    // This call should stop all haptics as soon as possible.
    // Return kUnitySubsystemErrorCodeSuccess if haptics could be stopped (even if already not running).
    XR_TRACE_LOG(s_XrTrace, "[XR Input Provider]: Handle Haptic Stop received.");

    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode QueryTrackingOriginMode(UnitySubsystemHandle handle, void* userData, UnityXRInputTrackingOriginModeFlags* trackingOriginMode)
{
    *trackingOriginMode = kUnityXRInputTrackingOriginModeDevice;
    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode QuerySupportedTrackingOriginModes(UnitySubsystemHandle handle, void* userData, UnityXRInputTrackingOriginModeFlags* supportedTrackingOriginModes)
{
    *supportedTrackingOriginModes = kUnityXRInputTrackingOriginModeDevice;
    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode HandleSetTrackingOriginMode(UnitySubsystemHandle handle, void* userData, UnityXRInputTrackingOriginModeFlags trackingOriginMode)
{
    return trackingOriginMode == kUnityXRInputTrackingOriginModeDevice ? kUnitySubsystemErrorCodeSuccess : kUnitySubsystemErrorCodeFailure;
}

/// Callback executed when a subsystem should initialize in preparation for becoming active.
static UnitySubsystemErrorCode UNITY_INTERFACE_API Lifecycle_Initialize(UnitySubsystemHandle handle, void* data)
{
    XR_TRACE_LOG(s_XrTrace, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    
    s_ProviderData.Reset();

    UnityXRInputProvider inputProvider;
    inputProvider.userData = NULL;
    inputProvider.Tick = &Tick;
    inputProvider.FillDeviceDefinition = &FillDeviceDefinition;
    inputProvider.UpdateDeviceState = &UpdateDeviceState;
    inputProvider.HandleEvent = &HandleEvent;
    inputProvider.HandleRecenter = &HandleRecenter;
    inputProvider.HandleHapticImpulse = &HandleHapticImpulse;
    inputProvider.HandleHapticBuffer = &HandleHapticBuffer;
    inputProvider.QueryHapticCapabilities = &QueryHapticCapabilities;
    inputProvider.HandleHapticStop = &HandleHapticStop;
    inputProvider.QueryTrackingOriginMode = &QueryTrackingOriginMode;
    inputProvider.QuerySupportedTrackingOriginModes = &QuerySupportedTrackingOriginModes;
    inputProvider.HandleSetTrackingOriginMode = &HandleSetTrackingOriginMode;

    //Tracking
    s_XrInput->RegisterInputProvider(handle, &inputProvider);

    return kUnitySubsystemErrorCodeSuccess;
}

static void SetVector3(UnityXRVector3& vector, float x, float y, float z)
{
    vector.x = x;
    vector.y = y;
    vector.z = z;
}

/// Callback executed when a subsystem should become active.
static UnitySubsystemErrorCode UNITY_INTERFACE_API Lifecycle_Start(UnitySubsystemHandle handle, void* data)
{
    s_ProviderData.Reset();
    s_XrInput->InputSubsystem_DeviceConnected(handle, kDeviceId_HMD);
    s_XrInput->InputSubsystem_DeviceConnected(handle, kDeviceId_Controller);

    UnityXRVector3 boundary[4];
    SetVector3(boundary[0], -1.f, 0.f, 1.f);
    SetVector3(boundary[1], 1.f, 0.f, 1.f);
    SetVector3(boundary[2], 1.f, 0.f, -1.f);
    SetVector3(boundary[3], -1.f, 0.f, -1.f);

    s_XrInput->InputSubsystem_SetTrackingBoundary(handle, boundary, 4);

    return kUnitySubsystemErrorCodeSuccess;
}

/// Callback executed when a subsystem should become inactive.
static void UNITY_INTERFACE_API Lifecycle_Stop(UnitySubsystemHandle handle, void* data)
{
    s_XrInput->InputSubsystem_DeviceDisconnected(handle, kDeviceId_HMD);
    s_XrInput->InputSubsystem_DeviceDisconnected(handle, kDeviceId_Controller);
}

/// Callback executed when a subsystem should release all resources and is about to be unloaded.
static void UNITY_INTERFACE_API Lifecycle_Shutdown(UnitySubsystemHandle handle, void* data)
{
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unityInterfaces)
{
    XR_TRACE_LOG(s_XrTrace, "!!!!!!!!!!!UnityPluginLoad!!!!!!!!!!!!!!!!!!!!");
    
    s_UnityInterfaces = unityInterfaces;
    s_XrInput = unityInterfaces->Get<IUnityXRInputInterface>();
    UnityLifecycleProvider inputLifecycleHandler = {
        NULL,
        &Lifecycle_Initialize,
        &Lifecycle_Start,
        &Lifecycle_Stop,
        &Lifecycle_Shutdown};
    s_XrInput->RegisterLifecycleProvider("XR SDK Input Sample", "input0", &inputLifecycleHandler);

    s_XrTrace = unityInterfaces->Get<IUnityXRTrace>();
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginUnload()
{
    
}
