#ifndef THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_LOAD_H_
#define THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_LOAD_H_

#include "IUnityInterface.h"
#include "XR/UnitySubsystemTypes.h"
#include "XR/UnityXRNativePtrs.h"

/// @brief Loads the Unity XR Display subsystem.
/// @param[in] xr_interfaces Unity XR interface provider to create the display
///            subsystem.
/// @return kUnitySubsystemErrorCodeSuccess When it succeeds to initialize the
///         display subsystem. Otherwise a valid Unity XR Subsystem error code
///         indicating the status of the failure.
UnitySubsystemErrorCode LoadDisplay(IUnityInterfaces* xr_interfaces);

/// @brief Loads the Unity XR Input subsystem.
/// @param[in] xr_interfaces Unity XR interface provider to create the input
///            subsystem.
/// @return kUnitySubsystemErrorCodeSuccess When it succeeds to initialize the
///         input subsystem. Otherwise a valid Unity XR Subsystem error code
///         indicating the status of the failure.
UnitySubsystemErrorCode LoadInput(IUnityInterfaces* xr_interfaces);

/// @brief Loads the Unity XR Input subsystem.
/// @param[in] xr_interfaces Unity XR interface provider to create the input
///            subsystem.
/// @return kUnitySubsystemErrorCodeSuccess When it succeeds to initialize the
///         input subsystem. Otherwise a valid Unity XR Subsystem error code
///         indicating the status of the failure.
void SetARSession(UnityXRNativeSession* ar_native_session);


#endif  // THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_LOAD_H_
