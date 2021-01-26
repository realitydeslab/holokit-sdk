#ifndef CARDBOARD_SDK_UNITY_XR_PROVIDER_LOAD_H_
#define CARDBOARD_SDK_UNITY_XR_PROVIDER_LOAD_H_

#include "IUnityInterface.h"
#include "XR/UnitySubsystemTypes.h"
#include "XR/UnityXRNativePtrs.h"

/// @brief Loads a UnityLifecycleProvider for the display provider.
///
/// @details Gets the trace and display interfaces from @p xr_interfaces and
///          initializes the UnityLifecycleProvider's callbacks with references
///          to `display_provider`'s methods. The subsystem is "Display", and
///          the plugin is "Cardboard". Callbacks are set just once in the
///          entire lifetime of the library (between UnityPluginLoad() and
///          UnityPluginUnload() invocations). Callbacks set to
///          UnityLifecycleProvider have a direct match with C#
///          {Create|Start|Stop|Destroy}Subsystem<XRDisplaySubsystem>() calls.
/// @param xr_interfaces Unity XR interface provider to create the display
///          subsystem.
/// @return kUnitySubsystemErrorCodeSuccess when the registration is successful.
///         Otherwise, a value in UnitySubsystemErrorCode flagging the error.
UnitySubsystemErrorCode LoadDisplay(IUnityInterfaces* xr_interfaces);

/// @brief Unloads the Unity XR Display subsystem.
void UnloadDisplay();

/// @brief Loads the Unity XR Input subsystem.
///
/// @details Gets the trace and display interfaces from @p xr_interfaces and
///          initializes the UnityLifecycleProvider's callbacks with references
///          to `cardboard_input_provider`'s methods. The subsystem is "Input",
///          and the plugin is "Cardboard". Callbacks are set just once in the
///          entire lifetime of the library (between UnityPluginLoad() and
///          UnityPluginUnload() invocations). Callbacks set to
///          UnityLifecycleProvider have a direct match with C#
///          {Create|Start|Stop|Destroy}Subsystem<XRInputSubsystem>() calls.
/// @param[in] xr_interfaces Unity XR interface provider to create the input
///            subsystem.
/// @return kUnitySubsystemErrorCodeSuccess when the registration is successful.
///         Otherwise, a value in UnitySubsystemErrorCode flagging the error.
UnitySubsystemErrorCode LoadInput(IUnityInterfaces* xr_interfaces);

/// @brief Unloads the Unity XR Input subsystem.
void UnloadInput();


void SetARSession(UnityXRNativeSession* ar_native_session);


#endif  // CARDBOARD_SDK_UNITY_XR_PROVIDER_LOAD_H_
