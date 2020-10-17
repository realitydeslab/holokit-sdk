#include "unity/xr_provider/load.h"
#include "XR/IUnityXRTrace.h"

// @def Logs to @p trace the @p message.
#define HOLOKIT_MAIN_XR_TRACE_LOG(trace, message) \
  XR_TRACE_LOG(trace, "[HoloKitXrMain]: " message "\n")

// @brief Loads an Unity XR Display and Input subsystems.
// @details It tries to load the display subsystem first, if it fails it
//          returns. Then, it continues with the input subsystem.
// @param unity_interfaces Unity Interface pointer.
extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unity_interfaces) {
  auto* xr_trace = unity_interfaces->Get<IUnityXRTrace>();

  if (LoadDisplay(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
      XR_TRACE_LOG(xr_trace, "Error loading display subsystem.");
    return;
  }
  HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace,
                              "Display subsystem successfully loaded.");

  if (LoadInput(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
      XR_TRACE_LOG(xr_trace, "Error loading input subsystem.");
    return;
  }
  HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "Input subsystem successfully loaded.");
}
