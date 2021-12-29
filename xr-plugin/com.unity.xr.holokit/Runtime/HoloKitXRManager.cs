using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.Management;
using UnityEngine.XR.ARSubsystems;

#if UNITY_INPUT_SYSTEM
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Layouts;
using UnityEngine.InputSystem.XR;
#endif

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace UnityEngine.XR.HoloKit
{
#if UNITY_INPUT_SYSTEM
    using UnityEngine.XR.HoloKit.Input;

#if UNITY_EDITOR
      [InitializeOnLoad]
#endif
    static class InputLayoutLoader
    {
        static InputLayoutLoader()
        {
            RegisterInputLayouts();
        }

        public static void RegisterInputLayouts()
        {
            UnityEngine.InputSystem.InputSystem.RegisterLayout<HoloKitHMD>(
                matches: new InputDeviceMatcher()
                    .WithInterface(XRUtilities.InterfaceMatchAnyVersion)
                    .WithProduct("(HoloKit HMD)")
            );

            UnityEngine.InputSystem.InputSystem.RegisterLayout<HoloKitHand>(
                matches: new InputDeviceMatcher()
                    .WithInterface(XRUtilities.InterfaceMatchAnyVersion)
                    .WithProduct("(HoloKit Hand)")
            );
        }
    }
    
#endif

    public class DisplaySampleXRManager
    {
        public const string kHoloKitDisplayProviderId = "HoloKit Display";
        public const string kHoloKitInputProviderId = "HoloKit Input";
        public static bool isHoloKitInitialized = false;

        public const string kARKitInputProviderId = "ARKit-Input";
        public const string kARKitMeshingProviderId = "ARKit-Meshing";


        //static XRDisplaySubsystemDescriptor GetHoloKitDisplaySubsystemDescriptor()
        //{
        //    List<XRDisplaySubsystemDescriptor> displayProviders = new List<XRDisplaySubsystemDescriptor>();
        //    SubsystemManager.GetSubsystemDescriptors(displayProviders);

        //    foreach (var d in displayProviders)
        //    {
        //        if (d.id.Equals(kHoloKitDisplayProviderId))
        //        {
        //            return d;
        //        }
        //    }
        //    return null;
        //}
        
        //static XRInputSubsystemDescriptor GetHoloKitInputSubsystemDescriptor()
        //{
        //    List<XRInputSubsystemDescriptor> inputProviders = new List<XRInputSubsystemDescriptor>();
        //    SubsystemManager.GetSubsystemDescriptors(inputProviders);

        //    foreach (var d in inputProviders)
        //    {
        //        //Debug.Log($"[HoloKitXRManager]: input provider {d.id.ToString()}");
        //        if (d.id.Equals(kHoloKitInputProviderId))
        //        {
        //            return d;
        //        }
        //    }
        //    return null;
        //}
        
        static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            List<XRSessionSubsystem> xrSessionSubsystems = new List<XRSessionSubsystem>();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);

            foreach (var d in xrSessionSubsystems)
            {
                return d;
            }
            return null;
        }
        

//        static void LoadHoloKitXRSubsystem() 
//        {
//            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
//            SubsystemManager.GetSubsystems(displaySubsystems);
//            foreach (var d in displaySubsystems)
//            {   
//                if (d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
//                {
//                    d.Start();
//                }
//            }
            
//            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
//            SubsystemManager.GetSubsystems(inputSubsystems);
//            foreach (var d in inputSubsystems)
//            {
//                if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
//                {
//                    d.Start();
//                }
//            }

//            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
//            if (xrSessionSubsystem != null)
//            {
//#if UNITY_IOS
//                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
//#endif
//            }

//#if UNITY_INPUT_SYSTEM
//            //InputLayoutLoader.RegisterInputLayouts();
//#endif
//        }

        //Before AfterAssembliesLoaded
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void OnSubsystemRegistration()
        {
            
        }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void OnAfterAssembliesLoaded() {
            
            var xrSettings = XRGeneralSettings.Instance;
            if (xrSettings == null)
            {
                return;
            }

            var xrManager = xrSettings.Manager;
            if (xrManager == null)
            {
                Debug.Log($"XRManagerSettings is null.");
                return;
            }
            // Manually load loaders
            foreach (var loader in xrManager.activeLoaders)
            {
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
                    isHoloKitInitialized = true;
                    loader.Initialize();
                }
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        static void OnBeforeSplashScreen() {

            if (!isHoloKitInitialized)
            {
                return;
            }
            var xrSettings = XRGeneralSettings.Instance;
            if (xrSettings == null)
            {
                Debug.Log($"XRGeneralSettings is null.");
                return;
            }

            var xrManager = xrSettings.Manager;
            if (xrManager == null)
            {
                Debug.Log($"XRManagerSettings is null.");
                return;
            }
            
            foreach (var loader in xrManager.activeLoaders)
            {
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
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
 
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void OnBeforeSceneLoad() {

        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void OnAfterSceneLoad() {
   
        }

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetARSession(IntPtr ptr);
    }
}