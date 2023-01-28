using System;
using System.Runtime.InteropServices;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit.NativeInterface
{
    public enum IOSThermalState
    {
        Nominal = 0,    // blue
        Fair = 1,       // green
        Serious = 2,    // yellow
        Critical = 3    // red
    }

    /// <summary>
    /// This class controls some iOS native functionalities which are necessary
    /// for HoloKit software development such as thermal state monitoring.
    /// </summary>
    public static class HoloKitIOSManagerNativeInterface
    {
        /// <summary>
        /// This function needs to be called at the beginning in order to receive
        /// iOS native callbacks. This function only needs to be called once.
        /// </summary>
        /// <param name="OnThermalStateChanged">Invoked when the iOS thermal state changes</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_RegisterIOSNativeDelegates(Action<int> OnThermalStateChanged);

        /// <summary>
        /// Get the current iOS thermal state.
        /// </summary>
        /// <returns>The index of the current thermal state</returns>
        [DllImport("__Internal")]
        private static extern int HoloKitSDK_GetThermalState();

        /// <summary>
        /// Get the current iOS system uptime.
        /// </summary>
        /// <returns>The current iOS system uptime</returns>
        [DllImport("__Internal")]
        private static extern double HoloKitSDK_GetSystemUptime();

        /// <summary>
        /// Set the screen brightness.
        /// </summary>
        /// <param name="brightness">Should be between 0 and 1</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetScreenBrightness(float brightness);

        /// <summary>
        /// Get the current screen brightness.
        /// </summary>
        /// <returns>The current screen brightness</returns>
        [DllImport("__Internal")]
        private static extern float HoloKitSDK_GetScreenBrightness();

        /// <summary>
        /// Links to an Objective-C delegate which is invoked when the iOS thermal
        /// state changes.
        /// </summary>
        /// <param name="state">The index of the new thermal state</param>
        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnThermalStateChangedDelegate(int state)
        {
            OnThermalStateChanged?.Invoke((IOSThermalState)state);
        }

        /// <summary>
        /// Invoked when the iOS thermal state changeds.
        /// </summary>
        public static event Action<IOSThermalState> OnThermalStateChanged;

        /// <summary>
        /// Call this function at the beginning of the app life cycle.
        /// </summary>
        public static void RegisterIOSNativeDelegates()
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_RegisterIOSNativeDelegates(OnThermalStateChangedDelegate);
            }
        }

        /// <summary>
        /// Get the current iOS thermal state.
        /// </summary>
        /// <returns>The current iOS thermal state</returns>
        public static IOSThermalState GetThermalState()
        {
            if (PlatformChecker.IsRuntime)
            {
                return (IOSThermalState)HoloKitSDK_GetThermalState();
            }
            else
            {
                return IOSThermalState.Nominal;
            }
        }

        /// <summary>
        /// Get the current iOS system uptime.
        /// </summary>
        /// <returns>The current iOS system uptime</returns>
        public static double GetSystemUptime()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_GetSystemUptime();
            }
            else
            {
                return 0;
            }
        }

        public static void SetScreenBrightness(float brightness)
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_SetScreenBrightness(brightness);
            }
        }

        public static float GetScreenBrightness()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_GetScreenBrightness();
            }
            else
            {
                return 1f;
            }
        }
    }
}
