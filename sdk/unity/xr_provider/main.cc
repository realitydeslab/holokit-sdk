#include "unity/xr_provider/load.h"
#include "XR/IUnityXRTrace.h"
#include "XR/UnityXRNativePtrs.h"

// @def Logs to @p trace the @p message.
#define CARDBOARD_MAIN_XR_TRACE_LOG(trace, message) \
  XR_TRACE_LOG(trace, "[CardboardXrMain]: " message "\n")

extern "C" {

// @note See https://docs.unity3d.com/Manual/NativePluginInterface.html for
// further information about UnityPluginLoad() and UnityPluginUnload().
// UnityPluginLoad() will be called just once when the first native call in C#
// is executed. Before the library is torn down,
// UnityPluginUnload() will be called to destruct and release all taken
// resources.

// @brief Loads Unity XR Display and Input subsystems.
// @details It tries to load the display subsystem first, if it fails it
//          returns. Then, it continues with the input subsystem.
// @param unity_interfaces Unity Interface pointer.
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unity_interfaces) {
  auto* xr_trace = unity_interfaces->Get<IUnityXRTrace>();
    CARDBOARD_MAIN_XR_TRACE_LOG(xr_trace,
                                "XXssdasdsadsssd");

  if (LoadDisplay(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
    CARDBOARD_MAIN_XR_TRACE_LOG(xr_trace, "Error loading display subsystem.");
    return;
  }
  CARDBOARD_MAIN_XR_TRACE_LOG(xr_trace,
                              "Display subsystem successfully loaded.");

  if (LoadInput(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
    CARDBOARD_MAIN_XR_TRACE_LOG(xr_trace, "Error loading input subsystem.");
    return;
  }
  CARDBOARD_MAIN_XR_TRACE_LOG(xr_trace, "Input subsystem successfully loaded.");
}

// @brief Unloads Unity XR Display and Input subsystems.
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginUnload() {
  UnloadDisplay();
  UnloadInput();
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    SetARSession(ar_native_session);
}

}  // extern "C"

