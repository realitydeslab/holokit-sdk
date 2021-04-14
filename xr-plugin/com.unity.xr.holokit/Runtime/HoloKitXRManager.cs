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
                Debug.Log($"[HoloKitXRManager]: input provider {d.id.ToString()}");
                if (d.id.Equals(kHoloKitInputProviderId))
                {
                    return d;
                }
            }
            return null;
        }
        
        
        static XRSessionSubsystem GetLoadedXRSessionSubsystem()
        {
            Debug.Log("[HoloKitXRManager]: GetLoadedXRSessionSubsystem()");
            List<XRSessionSubsystem> xrSessionSubsystems = new List<XRSessionSubsystem>();
            SubsystemManager.GetSubsystems(xrSessionSubsystems);

            foreach (var d in xrSessionSubsystems)
            {
                // if (d.running) 
                // {
                //Debug.Log("xrSession is founded. id" + d.subsystemDescriptor.id + "running" + d.running + " session id" + d.sessionId + " nativePtr" + d.nativePtr + " state" + d.trackingState);
                return d;
                //                }
            }
            return null;
        }
        

        static void LoadHoloKitXRSubsystem() 
        {
            Debug.Log("[HoloKitXRManager]: LoadHoloKitXRSubsystem()");
            
            //bool holokitDisplayStarted = false;
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            foreach (var d in displaySubsystems)
            {   
                Debug.Log("[HoloKitXRManager]: Loaded display subsystem " + d.subsystemDescriptor.id);
                
                if (d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
                {
                    d.Start();
                }
                
                /*
                if (d.running)
                {
                    
                    if (!d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
                    {
                        d.Stop();
                    }
                    else
                    {
                        Debug.Log("[HoloKitXRManager]: HoloKit Display subsystem has started automatically.");
                        holokitDisplayStarted = true;
                    }
                }
                */
            }
            /*
            if (!holokitDisplayStarted)
            {
                Debug.Log("[HoloKitXRManager]: HoloKit Display subsystem not started...");
                var holokitDisplaySubsystemDescriptor = GetHoloKitDisplaySubsystemDescriptor();
                if (holokitDisplaySubsystemDescriptor != null)
                {
                    var holokitDisplaySubsystem = holokitDisplaySubsystemDescriptor.Create();
                    if (holokitDisplaySubsystem != null)
                    {
                        Debug.Log("[HoloKitXRManger]: Manually start Holokit Display subsystem.");
                        holokitDisplaySubsystem.Start();
                    }
                }
            }
            */

            //bool holokitInputStarted = false;
            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(inputSubsystems);
            foreach (var d in inputSubsystems)
            {
                Debug.Log("[HoloKitXRManager]: Loaded input subsystem " + d.subsystemDescriptor.id);
                
                if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
                {
                    d.Start();
                }
                
                /*
                if (d.running)
                {
                    if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
                    {
                        Debug.Log("[HoloKitXRManager]: HoloKit Input subsystem has started automatically.");
                        holokitInputStarted = true;
                    }
                }
                */
            }
            /*
            if (!holokitInputStarted)
            {
                Debug.Log("[HoloKitXRManager]: HoloKit Input subsystem not started...");
                var holokitInputSubsystemDescriptor = GetHoloKitInputSubsystemDescriptor();
                if (holokitInputSubsystemDescriptor != null)
                {
                    var holokitInputSubsystem = holokitInputSubsystemDescriptor.Create();
                    if (holokitInputSubsystem != null)
                    {
                        Debug.Log("[HoloKitXRManger]: Manually start Holokit Input subsystem.");
                        holokitInputSubsystem.Start();
                    }
                }
            }
            */

            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
                Debug.Log("[HoloKitXRManager]: xrSessionSubsystem sessionId=" + xrSessionSubsystem.sessionId + " xrSessionSubsystem.trackingState=" + xrSessionSubsystem.trackingState + " xrSessionSubsystem.nativePtr=" + xrSessionSubsystem.nativePtr);
#if UNITY_IOS
                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
                Debug.Log("[HoloKitXRManager]: UnityHoloKit_SetARSession()");
#endif
            }

#if UNITY_INPUT_SYSTEM
            InputLayoutLoader.RegisterInputLayouts();
            //Debug.Log("<<<<<<<<<<RegisterInputLayours()");
#endif
            
        }

        //Before AfterAssembliesLoaded
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void OnSubsystemRegistration()
        {
            Debug.Log("[HoloKitXRManager]: OnSubsystemRegistration()");

            /*
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
            */
            //Debug.Log($"[HoloKitXRManager]: automaticLoading = {xrManager.automaticLoading}");
            //xrManager.automaticLoading = true;
            //xrManager.automaticRunning = true;

            // Manually load loaders
            //Debug.Log($"[HoloKitXRManager]: number of loaders: {xrManager.activeLoaders.Count}");
            //foreach (var loader in xrManager.activeLoaders)
            //{
            //    Debug.Log($"[HoloKitXRManager]: initialize {loader.name}");
            //    loader.Initialize();
            //}
        }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void OnAfterAssembliesLoaded() {
           Debug.Log("[HoloKitXRManager]: OnAfterAssembliesLoaded()");
            
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
            // Manually load loaders
            Debug.Log($"[HoloKitXRManager]: number of loaders: {xrManager.activeLoaders.Count}");
            foreach (var loader in xrManager.activeLoaders)
            {
                Debug.Log($"[HoloKitXRManager]: initialize {loader.name}");
                if (loader.name.Equals("Holo Kit XR Loader"))
                {
                    isHoloKitInitialized = true;
                }
                loader.Initialize();
            }
            
        }   

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        static void OnBeforeSplashScreen() {
            Debug.Log("[HoloKitXRManager]: OnBeforeSplashScreen()");

            if (isHoloKitInitialized)
            {
                LoadHoloKitXRSubsystem();
            }
        }
 
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void OnBeforeSceneLoad() {
            Debug.Log("[HoloKitXRManager]: OnBeforeSceneLoad() -> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void OnAfterSceneLoad() {
            Debug.Log("[HoloKitXRManager]: OnAfterSceneLoad() -> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetARSession(IntPtr ptr);

    }
}