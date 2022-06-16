using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARSubsystems;

namespace HoloKit {
    public enum ThermalState
    {
        ThermalStateNominal = 0,
        ThermalStateFair = 1,
        ThermalStateSerious = 2,
        ThermalStateCritical = 3
    }

    public enum CameraTrackingState
    {
        NotAvailable = 0,
        LimitedWithReasonNone = 1,
        LimitedWithReasonInitializing = 2,
        LimitedWithReasonExcessiveMotion = 3,
        LimitedWithReasonInsufficientFeatures = 4,
        LimitedWithReasonRelocalizing = 5,
        Normal = 6
    }

    public enum ARWorldMappingStatus
    {
        ARWorldMappingStatusNotAvailable = 0,
        ARWorldMappingStatusLimited = 1,
        ARWorldMappingStatusExtending = 2,
        ARWorldMappingStatusMapped = 3
    }

    public static class HoloKitARSessionControllerAPI
    {
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_InterceptUnityARSessionDelegate(IntPtr ptr);

        [DllImport("__Internal")]
        private static extern int HoloKitSDK_GetThermalState();

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetSessionShouldAttemptRelocalization(bool value);

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetScaningEnvironment(bool value);

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_GetCurrentARWorldMap();

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_RegisterARSessionControllerDelegates(
            Action<int> OnThermalStateChanged,
            Action<int> OnCameraChangedTrackingState,
            Action<int> OnARWorldMapStatusChanged,
            Action OnGotCurrentARWorldMap);

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnThermalStateChangedDelegate(int state)
        {
            OnThermalStateChanged?.Invoke((ThermalState)state);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnCameraChangedTrackingStateDelegate(int state)
        {
            OnCameraChangedTrackingState?.Invoke((CameraTrackingState)state);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnARWorldMapStatusChangedDelegate(int status)
        {
            OnARWorldMapStatusChanged?.Invoke((ARWorldMappingStatus)status);
        }

        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnGotCurrentARWorldMapDelegate()
        {
            OnGotCurrentARWorldMap?.Invoke();
        }

        public static event Action<ThermalState> OnThermalStateChanged;

        public static event Action<CameraTrackingState> OnCameraChangedTrackingState;

        public static event Action<ARWorldMappingStatus> OnARWorldMapStatusChanged;

        public static event Action OnGotCurrentARWorldMap;

        private static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            List<XRSessionSubsystem> xrSessionSubsystems = new();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);
            foreach (var subsystem in xrSessionSubsystems)
            {
                return subsystem;
            }
            Debug.Log("[HoloKitSDK] Failed to get loaded xr session subsystem");
            return null;
        }

        public static void InterceptUnityARSessionDelegate()
        {
            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
                HoloKitSDK_InterceptUnityARSessionDelegate(xrSessionSubsystem.nativePtr);
            }
        }

        public static ThermalState GetThermalState()
        {
            return (ThermalState)HoloKitSDK_GetThermalState();
        }

        public static void SetSessionShouldAttemptRelocalization(bool value)
        {
            HoloKitSDK_SetSessionShouldAttemptRelocalization(value);
        }

        public static void SetScaningEnvironment(bool value)
        {
            HoloKitSDK_SetScaningEnvironment(value);
        }

        public static void GetCurrentARWorldMap()
        {
            HoloKitSDK_GetCurrentARWorldMap();
        }

        public static void RegisterARSessionControllerDelegates()
        {
            HoloKitSDK_RegisterARSessionControllerDelegates(
                OnThermalStateChangedDelegate,
                OnCameraChangedTrackingStateDelegate,
                OnARWorldMapStatusChangedDelegate,
                OnGotCurrentARWorldMapDelegate);
        }
    }
}