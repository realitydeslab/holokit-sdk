using System.Runtime.InteropServices;
using UnityEngine;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit.NativeInterface
{
    public static class HoloKitDeviceProfileNativeInterface
    {
        /// <summary>
		/// Check if the current device is supported by HoloKit.
		/// </summary>
		/// <returns>Whether the device is supported</returns>
        [DllImport("__Internal")]
        private static extern bool HoloKitSDK_IsSupported();

        /// <summary>
		/// Check if the current device is an iPad.
		/// </summary>
		/// <returns>Whether the device is an iPad</returns>
        [DllImport("__Internal")]
        private static extern bool HoloKitSDK_IsIpad();

        /// <summary>
		/// Check if the current device supports LiDAR sensor.
		/// </summary>
		/// <returns>Whether the device supports LiDAR</returns>
        [DllImport("__Internal")]
        private static extern bool HoloKitSDK_SupportsLiDAR();

        /// <summary>
		/// Get the horizontal alighment marker offset in meters.
		/// </summary>
		/// <returns>Offset in meters</returns>
        [DllImport("__Internal")]
        private static extern float HoloKitSDK_GetHorizontalAlignmentMarkerOffset();

        /// <summary>
		/// Get the screen dpi of the current device.
		/// </summary>
		/// <returns>The device screen dpi</returns>
        [DllImport("__Internal")]
        private static extern float HoloKitSDK_GetScreenDpi();

        public static bool IsSupported()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_IsSupported();
            }
            else
            {
                return true;
            }
        }

        public static bool IsIpad()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_IsIpad();
            }
            else
            {
                return false;
            }
        }

        public static bool SupportsLiDAR()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_SupportsLiDAR();
            }
            else
            {
                return true;
            }
        }

        public static float GetHorizontalAlignmentMarkerOffset()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_GetHorizontalAlignmentMarkerOffset();
            }
            else
            {
                return 0.05075f;
            }
        }

        public static float GetScreenDpi()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_GetScreenDpi();
            }
            else
            {
                return Screen.dpi;
            }
        }
    }
}
