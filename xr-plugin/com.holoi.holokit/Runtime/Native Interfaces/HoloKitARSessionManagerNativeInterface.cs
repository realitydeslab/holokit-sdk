using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARSubsystems;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit.NativeInterface
{
    public enum BackgroundVideoFormat
    {
        VideoFormat2K = 0,
        VideoFormat4K = 1,
        VideoFormat4KHDR = 2
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

    /// <summary>
    /// This class intercepts ARKit's ARSessionDelegates from ARFoundation.
    /// </summary>
    public static class HoloKitARSessionManagerNativeInterface
    {
        /// <summary>
        /// This function needs to be called before the first ARSession arrives
        /// so that we can receive Objective-C callbacks. This function only needs
        /// to be called once.
        /// </summary>
        /// <param name="OnARSessionUpdatedFrame">Invoked when ARKit updated a new frame</param>
        /// <param name="OnCameraChangedTrackingState">Invoked when the camera tracking state changed</param>
        /// <param name="OnRelocalizationSucceeded">Invoked when relocalization succeeded</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_RegisterARSessionDelegates(Action<double, IntPtr> OnARSessionUpdatedFrame,
                                                                         Action<int> OnCameraChangedTrackingState,
                                                                         Action OnRelocalizationSucceeded);

        /// <summary>
        /// This function also needs to be called before the first ARSession arrives
        /// so that we can intercept ARKit's ARSessionDelegates from ARFoundation.
        /// This function needs to be called before every new ARSession.
        /// </summary>
        /// <param name="nativeARSessionPtr"></param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_InterceptUnityARSessionDelegates(IntPtr nativeARSessionPtr);

        /// <summary>
        /// Set this to true to force the device to relocalize after its ARSession
        /// has been interrupted. When set this to false, the ARSession will refresh
        /// after being interrupted.
        /// </summary>
        /// <param name="shouldRelocalize">Whether to relocalize after being interrupted</param>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetSessionShouldAttemptRelocalization(bool shouldRelocalize);

        [DllImport("__Internal")]
        private static extern void HoloKitSDK_SetBackgroundVideoFormat(int videoFormat);

        /// <summary>
        /// Pause the current ARSession.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_PauseCurrentARSession();

        /// <summary>
        /// Resume the paused ARSession.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void HoloKitSDK_ResumeCurrentARSession();

        /// <summary>
        /// Links to an Objective-C delegate which is invoked when ARKit updates a new ARSession frame. 
        /// </summary>
        /// <param name="timestamp">The timestamp of the ARFrame</param>
        /// <param name="matrixPtr">The pointer of the camera pose matrix</param>
        [AOT.MonoPInvokeCallback(typeof(Action<double, IntPtr>))]
        private static void OnARSessionUpdatedFrameDelegate(double timestamp, IntPtr matrixPtr)
        {
            if (OnARSessionUpdatedFrame == null)
                return;

            float[] matrixData = new float[16];
            Marshal.Copy(matrixPtr, matrixData, 0, 16);
            Matrix4x4 matrix = new();
            for (int i = 0; i < 4; i++)
            {
                for (int j = 0; j < 4; j++)
                {
                    matrix[i, j] = matrixData[(4 * i) + j];
                }
            }
            OnARSessionUpdatedFrame(timestamp, matrix);
        }

        /// <summary>
        /// Links to an Objective-C delegate which is invoked when camera tracking state changes.
        /// </summary>
        /// <param name="state">The index of the new camera tracking state</param>
        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnCameraChangedTrackingStateDelegate(int state)
        {
            OnCameraChangedTrackingState?.Invoke((CameraTrackingState)state);
        }

        /// <summary>
        /// Links to an Objective-C delegate which is invoked when relocalization succeeds.
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnRelocalizationSucceededDelegate()
        {
            OnRelocalizationSucceeded?.Invoke();
        }

        /// <summary>
        /// Invoked when ARKit updates a new ARFrame.
        /// </summary>
        public static event Action<double, Matrix4x4> OnARSessionUpdatedFrame;

        /// <summary>
        /// Invoked when camera tracking state changes.
        /// </summary>
        public static event Action<CameraTrackingState> OnCameraChangedTrackingState;

        /// <summary>
        /// Invoked when relocalization succeeds.
        /// </summary>
        public static event Action OnRelocalizationSucceeded;

        public static void RegisterARSessionDelegates()
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_RegisterARSessionDelegates(OnARSessionUpdatedFrameDelegate,
                                                      OnCameraChangedTrackingStateDelegate,
                                                      OnRelocalizationSucceededDelegate);
            }
        }

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

        public static void InterceptUnityARSessionDelegates()
        {
            if (PlatformChecker.IsEditor)
            {
                return;
            }

            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
                HoloKitSDK_InterceptUnityARSessionDelegates(xrSessionSubsystem.nativePtr);
                Debug.Log("[HoloKitSDK] Unity ARSessionDelegates intercepted");
            }
        }

        public static void SetSessionShouldAttemptRelocalization(bool shouldRelocalize)
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_SetSessionShouldAttemptRelocalization(shouldRelocalize);
            }
        }

        public static void SetBackgroundVideoFormat(BackgroundVideoFormat videoFormat)
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_SetBackgroundVideoFormat((int)videoFormat);
            }
        }

        public static void PauseCurrentARSession()
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_PauseCurrentARSession();
            }
        }

        public static void ResumeCurrentARSession()
        {
            if (PlatformChecker.IsRuntime)
            {
                HoloKitSDK_ResumeCurrentARSession();
            }
        }
    }
}
