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
        public const string kHoloKitDisplayProviderId = "Display Sample";
        public const string kHoloKitInputProviderId = "Head Tracking Sample";
        public const string kArKitInputProviderId = "ARKit-Input";
        
        static XRDisplaySubsystemDescriptor GetHoloKitDisplaySubsystemDescriptor()
        {
            List<XRDisplaySubsystemDescriptor> displayProviders = new List<XRDisplaySubsystemDescriptor>();
            SubsystemManager.GetSubsystemDescriptors(displayProviders);

            foreach (var d in displayProviders)
            {
                if (d.id.Equals(kHoloKitDisplayProviderId))
                {
                    Debug.Log("++++++++++ found display provider");
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
                    Debug.Log("++++++++++ found head tracking input provider");
                    return d;
                }
            }
            return null;
        }

        // arkit
        static XRInputSubsystemDescriptor GetArKitInputSubsystemDescriptor()
        {
            List<XRInputSubsystemDescriptor> inputProviders = new List<XRInputSubsystemDescriptor>();
            SubsystemManager.GetSubsystemDescriptors(inputProviders);

            foreach (var d in inputProviders)
            {
                if (d.id.Equals(kArKitInputProviderId))
                {
                    Debug.Log("++++++++++ found arkit input provider");
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
                //Debug.Log("xrSession is founded. id" + d.subsystemDescriptor.id + "running" + d.running + " session id" + d.sessionId + " nativePtr" + d.nativePtr + " state" + d.trackingState);
                return d;
                //                }
            }
            return null;
        }
        

        static void LoadHoloKitXRSubsystem() 
        {
            /*
            Debug.Log("XRManager::LoadHoloKitXRSubsystem()");
            //Debug.Log("Input providers:");
            List<XRInputSubsystemDescriptor> inputProviders = new List<XRInputSubsystemDescriptor>();
            SubsystemManager.GetSubsystemDescriptors(inputProviders);
            foreach (var d in inputProviders)
            {
                //Debug.Log("Input Provider: " + d.id); 
            }

            //Debug.Log("Input subsystems:");
            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(inputSubsystems);
            foreach (var d in inputSubsystems)
            {
                //Debug.Log("Input Subsystem: " + d.subsystemDescriptor.id);
            }
            */
            
            // arkit stuff
            /*
            bool arkitInputStarted = false;
            List<XRInputSubsystem> arkitInputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(arkitInputSubsystems);
            foreach (var d in arkitInputSubsystems)
            {
                if (d.running)
                {
                    if (d.subsystemDescriptor.id.Equals(kArKitInputProviderId))
                    {
                        Debug.Log("++++++++++ arkit input subsystem has started automatically");
                        arkitInputStarted = true;
                    }
                }
            }

            if (!arkitInputStarted)
            {
                var arkitInputSubsystemDescriptor = GetArKitInputSubsystemDescriptor();
                if (arkitInputSubsystemDescriptor != null)
                {
                    var arkitInputSubsystem = arkitInputSubsystemDescriptor.Create();
                    if (arkitInputSubsystem != null)
                    {
                        Debug.Log("+++++++++++ try manually start arkit input subsystem");
                        arkitInputSubsystem.Start();
                    }
                }
            }
            */
            
            bool holokitDisplayStarted = false;
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            foreach (var d in displaySubsystems)
            {   
                Debug.Log("++++++++++ lalala");
                Debug.Log("LoadHoloKitXRSubsystem " + d.subsystemDescriptor.id);

                if (d.running)
                {
                    
                    if (!d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
                    {
                        Debug.Log("sorry got another display provider...");
                        d.Stop();
                    }
                    else
                    {
                        Debug.Log("++++++++++ holokit display subsystem has started automatically");
                        holokitDisplayStarted = true;
                    }
                    
                    //if (d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
                    //{
                    //    Debug.Log("++++++++++ holokit display subsystem has started automatically");
                    //    holokitDisplayStarted = true;
                    //}
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
                       Debug.Log("++++++++++ try manually start holokit display subsystem");
                        holokitDisplaySubsystem.Start();
                    }
                }
            }
            
            /*
            bool holokitInputStarted = false;
            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(inputSubsystems);
            foreach (var d in inputSubsystems)
            {
                if (d.running)
                {
                    if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
                    {
                        Debug.Log("++++++++++ holokit input subsystem has started automatically");
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
                        Debug.Log("+++++++++++ try manually start holokit input subsystem");
                        holokitInputSubsystem.Start();
                    }
                }
            }
            */
            
            var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
            if (xrSessionSubsystem != null)
            {
                //Debug.Log("[LoadHoloKitXRSubsystem] xrSessionSubsystem sessionId=" + xrSessionSubsystem.sessionId + " xrSessionSubsystem.trackingState=" + xrSessionSubsystem.trackingState + " xrSessionSubsystem.nativePtr=" + xrSessionSubsystem.nativePtr);
                //Debug.Log("[LoadHoloKitXRSubsystem] Setup xrSessionSubsystem");
#if UNITY_IOS
                UnityHoloKit_SetARSession(xrSessionSubsystem.nativePtr);
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
            Debug.Log("[OnSubsystemRegistration] Start");

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

            Debug.Log($"[OnSubsystemRegistration] Set automaticloading = false.");
            xrManager.automaticLoading = false;
            
            // do something here
            // manually force to initialize all loaders
            Debug.Log("sorry this is the lab oooooooo");
            Debug.Log($"number of loaders: {xrManager.loaders.Count}");
            //Debug.Log($"number of registered loaders: {xrManager.}")
            foreach(var loader in xrManager.loaders)
            {   
                Debug.Log($"trying to initialize loader number");
                loader.Initialize();
            }
            
        }
        
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void OnAfterAssembliesLoaded() {
           Debug.Log("[OnAfterAssembliesLoaded] Start");
           
        }   

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
        static void OnBeforeSplashScreen() {
            Debug.Log("[OnBeforeSplashScreen] Start");

            //Debug.Log("xrManager loaders");
            Debug.Log("++++++++++ before LoadHoloKitXRSubsystem()");
            LoadHoloKitXRSubsystem();
            Debug.Log("++++++++++ after LoadHoloKitXRSubsystem()");
        }
 
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void OnBeforeSceneLoad() {
            Debug.Log("[OnBeforeSceneLoad] ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void OnAfterSceneLoad() {
            Debug.Log("[OnAfterSceneLoad] ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
            
        }

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetARSession(IntPtr ptr);

    }
}