using UnityEngine;
using Holoi.HoloKit.NativeInterface;

namespace Holoi.HoloKit
{
    public static class HoloKitDeviceProfile
    {
        public static bool IsSupported()
        {
            return HoloKitDeviceProfileNativeInterface.IsSupported();
        }

        public static bool IsIpad()
        {
            return HoloKitDeviceProfileNativeInterface.IsIpad();
        }

        public static bool SupportsLiDAR()
        {
            return HoloKitDeviceProfileNativeInterface.SupportsLiDAR();
        }

        public static float GetHorizontalAlignmentMarkerOffset()
        {
            return HoloKitDeviceProfileNativeInterface.GetHorizontalAlignmentMarkerOffset();
        }

        public static float GetScreenDpi()
        {
            return HoloKitDeviceProfileNativeInterface.GetScreenDpi();
        }

        /// <summary>
        /// Get the screen width in pixels. This should always be the longer side of the screen.
        /// </summary>
        /// <returns>Screen width in pixels</returns>
        public static float GetScreenWidth()
        {
            return Screen.width > Screen.height ? Screen.width : Screen.height;
        }

        /// <summary>
        /// Get the screen height in pixels. This should always be the shorter side of the screen.
        /// </summary>
        /// <returns>Screen height in pixels</returns>
        public static float GetScreenHeight()
        {
            return Screen.width < Screen.height ? Screen.width : Screen.height;
        }
    }
}
