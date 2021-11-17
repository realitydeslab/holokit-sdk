using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitApi
    {
        [DllImport("__Internal")]
        private static extern string UnityHoloKit_GetDeviceName();

        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetDeviceScreenWidth();

        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetDeviceScreenHeight();
    }
}
