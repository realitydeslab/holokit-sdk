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

    public class HoloKitXRManager
    {
        public  const string kHoloKitDisplayProviderId = "HoloKit-Display";
        public  const string kHoloKitInputProviderId = "HoloKit-Input";

        static XRDisplaySubsystemDescriptor GetHoloKitDisplaySubsystemDescriptor()
        {
            List<XRDisplaySubsystemDescriptor> displayProviders = new List<XRDisplaySubsystemDescriptor>();
            SubsystemManager.GetSubsystemDescriptors(displayProviders);

            foreach (var d in displayProviders)
            {
                if (d.id.Equals(kHoloKitDisplayProviderId))
                {
                    return d;
                }
            }
            return null;
        }

        static XRInputSubsystemDescriptor GetHoloKitInputSubsystemDescriptor()
        {
            List<XRInputSubsystemDescriptor> inputProviders = new List<XRInputSubsystemDescriptor>();
            SubsystemManager.GetSubsystemDescriptors(inputProviders);

            foreach (var d in inputProviders)
            {
                if (d.id.Equals(kHoloKitInputProviderId))
                {
                    return d;
                }
            }
            return null;
        }

        static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            List<XRSessionSubsystem> xrSessionSubsystems = new List<XRSessionSubsystem>();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);

            foreach (var d in xrSessionSubsystems)
            {
                // if (d.running) 
                // {
                    Debug.Log("xrSession is founded. id" + d.subsystemDescriptor.id + "running" + d.running + " session id" + d.sessionId + " nativePtr" + d.nativePtr + " state" + d.trackingState);
                    return d;
//                }
            }
            return null;
        }



        //Before AfterAssembliesLoaded
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void OnSubsystemRegistration ()
        {
            Debug.LogWarning("OnSubsystemRegistration");
        
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
            Debug.Log($"Set automaticloading = false.");
            xrManager.automaticLoading = false;
         }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void OnAfterAssembliesLoaded() {
           Debug.LogWarning("OnAfterAssembliesLoaded");
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        static void OnBeforeSplashScreen() {
           Debug.LogWarning("OnBeforeSplashScreen");

             bool holokitDisplayStarted = false;
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            foreach (var d in displaySubsystems)
            {
                 Debug.Log("BeforeSplashScreen Current" + d.subsystemDescriptor.id);

                if (d.running)
                {
                    if (!d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
                    {                        
                        d.Stop();
                    }
                    else
                    {
                        holokitDisplayStarted = true;
                    }
                }
            }

            if (!holokitDisplayStarted)
            {
                var holokitDisplaySubsystemDescriptor = GetHoloKitDisplaySubsystemDescriptor();
                if (holokitDisplaySubsystemDescriptor != null)
                {
                    var holokitDisplaySubsystem = holokitDisplaySubsystemDescriptor.Create();
                    if (holokitDisplaySubsystem != null)
                    {
                       holokitDisplaySubsystem.Start();
                    }
                }
            }

            bool holokitInputStarted = false;
            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(inputSubsystems);
            foreach (var d in inputSubsystems)
            {
                if (d.running)
                {
                    if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
                    {
                        holokitInputStarted = true;
                    }
                }
            }

            if (!holokitInputStarted)
            {
                var holokitInputSubsystemDescriptor = GetHoloKitInputSubsystemDescriptor();
                if (holokitInputSubsystemDescriptor != null)
                {
                    var holokitInputSubsystem = holokitInputSubsystemDescriptor.Create();
                    if (holokitInputSubsystem != null)
                    {
                        holokitInputSubsystem.Start();
                    }
                }
            }

            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null) {
                Debug.Log("xrSessionSubsystem" + xrSessionSubsystem.sessionId + " " + xrSessionSubsystem.trackingState + " " + xrSessionSubsystem.nativePtr);
                Debug.Log("Setup xrSessionSubsystem");
                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
            }

#if UNITY_INPUT_SYSTEM
            InputLayoutLoader.RegisterInputLayouts();
#endif
        }
 
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void OnBeforeSceneLoad() {
            Debug.LogWarning("OnBeforeSceneLoad ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void OnAfterSceneLoad() {
            Debug.LogWarning("OnAfterSceneLoad ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }


        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetARSession(IntPtr ptr);

    }
}
