using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.XR.Management;
using UnityEngine.XR.ARSubsystems;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitXRManager
    {
        public const string kHoloKitDisplayProviderId = "HoloKit Display";
        public const string kHoloKitInputProviderId = "HoloKit Input";
        public static bool isHoloKitInitialized = false;

        public const string kARKitInputProviderId = "ARKit-Input";
        public const string kARKitMeshingProviderId = "ARKit-Meshing";

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARSession(IntPtr ptr);

        private static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            List<XRSessionSubsystem> xrSessionSubsystems = new List<XRSessionSubsystem>();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);

            foreach (var d in xrSessionSubsystems)
            {
                return d;
            }
            return null;
        }
        
        //Before AfterAssembliesLoaded
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void OnSubsystemRegistration()
        {
            
        }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        private static void OnAfterAssembliesLoaded()
        {

        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        private static void OnBeforeSplashScreen()
        {

        }
 
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void OnBeforeSceneLoad()
        {
            foreach (var loader in XRGeneralSettings.Instance.Manager.activeLoaders)
            {
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
                    loader.Initialize();
                    loader.Start();
                }
            }

            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
#if UNITY_IOS
                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
#endif
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void OnAfterSceneLoad()
        {

        }
    }
}