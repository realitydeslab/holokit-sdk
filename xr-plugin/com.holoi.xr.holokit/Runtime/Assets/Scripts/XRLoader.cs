using UnityEngine.XR.Management;
using UnityEngine.XR.ARSubsystems;
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

namespace UnityEngine.XR.HoloKit
{
    public static class XRLoader
    {
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARSession(IntPtr ptr);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_InitializeHoloKitApi();

        private static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            List<XRSessionSubsystem> xrSessionSubsystems = new();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);

            foreach (var d in xrSessionSubsystems)
            {
                return d;
            }
            return null;
        }

        public static void InitializeHoloKitApi()
        {
            Debug.Log("[XRLoader] Initialize HoloKitApi");
            UnityHoloKit_InitializeHoloKitApi();
        }

        public static void InitializeHoloKitSubsystems()
        {
            Debug.Log("[XRLoader] Initialize HoloKit Subsystems");
            foreach (var loader in XRGeneralSettings.Instance.Manager.activeLoaders)
            {
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
                    loader.Initialize();
                    loader.Start();
                }
            }
        }

        public static void DeinitializeHoloKitSubsystems()
        {
            Debug.Log("[XRLoader] Deinitialize HoloKit Subsystems");
            foreach (var loader in XRGeneralSettings.Instance.Manager.activeLoaders)
            {
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
                    loader.Stop();
                    loader.Deinitialize();
                }
            }
        }

        public static void RegisterARSessionDelegates()
        {
            Debug.Log("[XRLoader] RegisterARSessionDelegates");
            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
            }
        }

        public static void InitializeARKit()
        {
            Debug.Log("[XRLoader] Initialize ARKit");
            XRGeneralSettings.Instance.Manager.InitializeLoaderSync();
            XRGeneralSettings.Instance.Manager.StartSubsystems();
        }

        public static void DeinitializeARKit()
        {
            Debug.Log("[XRLoader] Deinitialize ARKit");
            XRGeneralSettings.Instance.Manager.StopSubsystems();
            XRGeneralSettings.Instance.Manager.DeinitializeLoader();
        }

        // Initialize both ARKit and HoloKit.
        public static void InitializeEverything()
        {
            InitializeARKit();
            InitializeHoloKitApi();
            InitializeHoloKitSubsystems();
            RegisterARSessionDelegates();
        }


        // Deinitialize both ARKit and HoloKit.
        public static void DeinitializeEverything()
        {
            DeinitializeHoloKitSubsystems();
            DeinitializeARKit();
        }
    }
}
