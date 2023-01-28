using System;
using System.Runtime.InteropServices;
using UnityEngine;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit.NativeInterface
{
    public static class HoloKitHandTrackerNativeInterface
    {
        /// <summary>
        /// This function needs to be called before performing any hand tracking
        /// request. This function only needs to be called once.
        /// </summary>
        /// <param name="OnHandPoseUpdated">Invoked when hand pose updates</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_RegisterHandTrackerDelegates(Action<int, IntPtr> OnHandPoseUpdated);

        /// <summary>
        /// Set the number of hands to be detected. The value can only be either
        /// 1 or 2. The default count is 1.
        /// </summary>
        /// <param name="maxHandCount">The maximum number of hands to be detected</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetMaxHandCount(int maxHandCount);

        /// <summary>
        /// Get the maxinum number of hands to be detected.
        /// </summary>
        /// <returns>The maximum number of hands to be detected</returns>
        [DllImport("__Internal")]
        private static extern int HoloKitSDK_GetMaxHandCount();

        /// <summary>
        /// Turn on or off the hand tracking functionality.
        /// </summary>
        /// <param name="enabled">Set true to turn on and false to turn off</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetHandTrackerEnabled(bool enabled);

        /// <summary>
        /// Links to an Objective-C delegate which is invoked when a new hand pose
        /// is detected.
        /// </summary>
        /// <param name="handIndex">The index of the detected hand</param>
        /// <param name="handDataPtr">The pointer pointing to the hand pose data</param>
        [AOT.MonoPInvokeCallback(typeof(Action<IntPtr>))]
        private static void OnHandPoseUpdatedDelegate(int handIndex, IntPtr handDataPtr)
        {
            float[] handData = new float[63];
            Marshal.Copy(handDataPtr, handData, 0, 63);
            OnHandPoseUpdated?.Invoke(handIndex, handData);
        }

        /// <summary>
        /// Invoked when a new hand pose is detected.
        /// </summary>
        public static event Action<int, float[]> OnHandPoseUpdated;

        public static void RegisterHandTrackerDelegates()
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_RegisterHandTrackerDelegates(OnHandPoseUpdatedDelegate);
            }
        }

        public static void SetMaxHandCount(int maxHandCount)
        {
            if (PlatformChecker.IsRuntime)
            {
                if (maxHandCount == 1 || maxHandCount == 2)
                {
                    HoloKitSDK_SetMaxHandCount(maxHandCount);
                }
                else
                {
                    Debug.Log("[HoloKitSDK] MaxHandCount can either be 1 or 2");
                }
            }
        }

        public static int GetMaxHandCount()
        {
            if (PlatformChecker.IsRuntime)
            {
                return HoloKitSDK_GetMaxHandCount();
            }
            else
            {
                return 2;
            }
        }

        public static void SetHandTrackerEnabled(bool enabled)
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_SetHandTrackerEnabled(enabled);
            }
        }
    }
}