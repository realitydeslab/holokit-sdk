using System.Runtime.InteropServices;
using System;

namespace UnityEngine.XR.HoloKit
{
    public enum ARKitCameraTrackingState
    {
        NotAvailable = 0,
        LimitedWithReasonNone = 1,
        LimitedWithReasonInitializing = 2,
        LimitedWithReasonExcessiveMotion = 3,
        LimitedWithReasonInsufficientFeatures = 4,
        LimitedWithReasonRelocalizing = 5,
        Normal = 6
    }

    public enum iOSThermalState
    {
        ThermalStateNominal = 0,
        ThermalStateFair = 1,
        ThermalStateSerious = 2,
        ThermalStateCritical = 3
    }

    public static class HoloKitApi
    {
        #region ARSession
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetWorldOrigin(float[] position, float[] rotation);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSessionShouldAttemptRelocalization(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(Action<int> callback);

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnCameraDidChangeTrackingState(int state)
        {
            CameraDidChangeTrackingStateEvent?.Invoke((ARKitCameraTrackingState)state);
        }

        public static event Action<ARKitCameraTrackingState> CameraDidChangeTrackingStateEvent;
        #endregion

        #region iOS Thermal
        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetThermalState();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetThermalStateDidChangeDelegate(Action<int> callback);

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnThermalStateDidChange(int state)
        {
            ThermalStateDidChangeEvent?.Invoke((iOSThermalState)state);
        }

        public static event Action<iOSThermalState> ThermalStateDidChangeEvent;
        #endregion

        #region HoloKit SDK
        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetDeviceScreenWidth();

        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetDeviceScreenHeight();

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_GetStereoscopicRendering();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetStereoscopicRendering(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetUsingNfc(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_StartNfcAuthentication();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetNfcAuthenticationDidCompleteDelegate(Action<bool> callback);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSetARCameraBackgroundDelegate(Action<bool> value);

        [AOT.MonoPInvokeCallback(typeof(Action<bool>))]
        private static void OnNfcAuthenticationDidComplete(bool success)
        {
            NfcAuthenticationDidCompleteEvent?.Invoke(success);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<bool>))]
        private static void OnSetARCameraBackground(bool value)
        {
            SetARCameraBackgroundEvent?.Invoke(value);
        }

        public static event Action NfcAuthenticationDidStartEvent;

        public static event Action<bool> NfcAuthenticationDidCompleteEvent;

        public static event Action<bool> SetARCameraBackgroundEvent;
        #endregion

        public static void RegisterNfcDelegates()
        {
            UnityHoloKit_SetNfcAuthenticationDidCompleteDelegate(OnNfcAuthenticationDidComplete);
        }

        public static void UnregisterNfcDelegates()
        {
            UnityHoloKit_SetNfcAuthenticationDidCompleteDelegate(null);
        }

        public static void RegisterStARDelegates()
        {
            UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(OnCameraDidChangeTrackingState);
            UnityHoloKit_SetThermalStateDidChangeDelegate(OnThermalStateDidChange);
            //UnityHoloKit_SetSetARCameraBackgroundDelegate(OnSetARCameraBackground);
        }

        public static void UnregisterStARDelegates()
        {
            UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(null);
            UnityHoloKit_SetThermalStateDidChangeDelegate(null);
            //UnityHoloKit_SetSetARCameraBackgroundDelegate(null);
        }

        public static void SetWorldOrigin(Vector3 position, Quaternion rotation)
        {
            float[] p = new float[] { position.x, position.y, position.z };
            float[] r = new float[] { rotation.x, rotation.y, rotation.z, rotation.w };
            UnityHoloKit_SetWorldOrigin(p, r);
        }

        public static void SetSessionShouldAttemptRelocalization(bool value)
        {
            UnityHoloKit_SetSessionShouldAttemptRelocalization(value);
        }

        public static iOSThermalState GetThermalState()
        {
            return (iOSThermalState)UnityHoloKit_GetThermalState();
        }

        public static int GetDeviceScreenWidth()
        {
            return UnityHoloKit_GetDeviceScreenWidth();
        }

        public static int GetDeviceScreenHeight()
        {
            return UnityHoloKit_GetDeviceScreenHeight();
        }

        public static bool GetStereoScopicRendering()
        {
            return UnityHoloKit_GetStereoscopicRendering();
        }

        public static void SetStereoScopicRendering(bool value)
        {
            UnityHoloKit_SetStereoscopicRendering(value);
        }

        public static void SetUsingNfc(bool value)
        {
            UnityHoloKit_SetUsingNfc(value);
        }

        public static void StartNfcAuthentication()
        {
            RegisterNfcDelegates();
            NfcAuthenticationDidStartEvent?.Invoke();
            UnityHoloKit_StartNfcAuthentication();
        }
    }
}
