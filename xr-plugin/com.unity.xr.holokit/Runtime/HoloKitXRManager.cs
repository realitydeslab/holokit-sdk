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
            bool holokitDisplayStarted = false;
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            foreach (var d in displaySubsystems)
            {   
                Debug.Log("LoadHoloKitXRSubsystem " + d.subsystemDescriptor.id);
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
            }

            if (!holokitDisplayStarted)
            {
                var holokitDisplaySubsystemDescriptor = GetHoloKitDisplaySubsystemDescriptor();
                if (holokitDisplaySubsystemDescriptor != null)
                {
                    var holokitDisplaySubsystem = holokitDisplaySubsystemDescriptor.Create();
                    if (holokitDisplaySubsystem != null)
                    {
                        Debug.Log("[HoloKitXRManger]: manually start Holokit Display subsystem.");
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
                        Debug.Log("[HoloKitXRManager]: HoloKit Input subsystem has started automatically.");
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
                        Debug.Log("[HoloKitXRManger]: manually start Holokit Input subsystem.");
                        holokitInputSubsystem.Start();
                    }
                }
            }
            
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

            Debug.Log($"[HoloKitXRManager]: automaticLoading = {xrManager.automaticLoading}");
            xrManager.automaticLoading = false;

            // manually force to initialize all loaders
            Debug.Log($"number of loaders: {xrManager.loaders.Count}");
            foreach (var loader in xrManager.loaders)
            {
                Debug.Log($"trying to initialize loader number");
                loader.Initialize();
            }

        }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void OnAfterAssembliesLoaded() {
           Debug.Log("[HoloKitXRManager]: OnAfterAssembliesLoaded()");
           
        }   

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        static void OnBeforeSplashScreen() {
            Debug.Log("[HoloKitXRManager]: OnBeforeSplashScreen()");

            //Debug.Log("xrManager loaders");
            LoadHoloKitXRSubsystem();
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