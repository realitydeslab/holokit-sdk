//
//  load.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include "IUnityInterface.h"
#include "UnitySubsystemTypes.h"
#include "holokit_xr_unity.h"

/// @brief Loads a UnityLifecycleProvider for the display provider.
///
/// @details Gets the trace and display interfaces from @p xr_interfaces and
///          initializes the UnityLifecycleProvider's callbacks with references
///          to `display_provider`'s methods. The subsystem is "Display", and
///          the plugin is "HoloKit". Callbacks are set just once in the
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
///          to `input_provider`'s methods. The subsystem is "Input",
///          and the plugin is "HoloKit". Callbacks are set just once in the
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
