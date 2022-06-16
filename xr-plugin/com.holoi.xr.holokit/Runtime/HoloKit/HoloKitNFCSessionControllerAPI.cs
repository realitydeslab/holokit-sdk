using System;
using System.Runtime.InteropServices;

namespace HoloKit
{
    public static class HoloKitNFCSessionControllerAPI
    {
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_EnableNFCSession(bool value);

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_StartNFCSession(string alertMessage);

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_RegisterNFCSessionControllerDelegates(Action<bool> OnNFCSessionCompleted);

        [AOT.MonoPInvokeCallback(typeof(Action<bool>))]
        private static void OnNFCSessionCompletedDelegate(bool success)
        {
            OnNFCSessionCompleted?.Invoke(success);
        }

        public static event Action<bool> OnNFCSessionCompleted;

        public static void EnableNFCSession(bool value)
        {
            HoloKitSDK_EnableNFCSession(value);
        }

        public static void StartNFCSession(string alertMessage)
        {
            HoloKitSDK_StartNFCSession(alertMessage);
        }

        public static void RegisterNFCSessionControllerDelegates()
        {
            HoloKitSDK_RegisterNFCSessionControllerDelegates(OnNFCSessionCompletedDelegate);
        }
    }
}