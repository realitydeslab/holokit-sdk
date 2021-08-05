//
//  main.cpp
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include "IUnityXRTrace.h"
#include "load.h"
#include "holokit_api.h"
#include "low-latency-tracking/low_latency_tracking_api.h"

// @def Logs to @p trace the @p message.
#define HOLOKIT_MAIN_XR_TRACE_LOG(trace, message) \
  XR_TRACE_LOG(trace, "[HoloKitXrMain]: " message "\n")

//IUnityInterfaces* unity_interfaces_;

extern "C" {

// @brief Loads Unity XR Display and Input subsystems.
// @details It tries to load the display subsystem first, if it fails it
//          returns. Then, it continues with the input subsystem.
// @param unity_interfaces Unity Interface pointer.
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unity_interfaces) {
    //unity_interfaces_ = unity_interfaces;
    auto* xr_trace = unity_interfaces->Get<IUnityXRTrace>();

    HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "UnityPluginLoad()\n");

    // Set up HoloKitApi instance.
    holokit::HoloKitApi::GetInstance().reset(new holokit::HoloKitApi);
    holokit::HoloKitApi::GetInstance()->Initialize();
    
    // Set up LowLatencyTrackingApi instance.

    if (LoadDisplay(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
        HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "Error loading HoloKit display subsystem.");
        return;
    }
    HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "HoloKit display subsystem successfully loaded.");

    if (LoadInput(unity_interfaces) != kUnitySubsystemErrorCodeSuccess) {
        HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "Error loading HoloKit input subsystem.");
            return;
    }
    HOLOKIT_MAIN_XR_TRACE_LOG(xr_trace, "HoloKit input subsystem successfully loaded.");
}

// @brief Unloads Unity XR Display and Input subsystems.
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginUnload() {
    UnloadDisplay();
    UnloadInput();
}

} // extern "C"
