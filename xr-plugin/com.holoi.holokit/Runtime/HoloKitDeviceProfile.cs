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

        public static float GetScreenWidth()
        {
            return Screen.width > Screen.height ? Screen.width : Screen.height;
        }

        public static float GetScreenHeight()
        {
            return Screen.width < Screen.height ? Screen.width : Screen.height;
        }
    }
}
