// using System;
// using System.Collections;
// using System.Collections.Generic;
// using System.Reflection;
// using System.Runtime.CompilerServices;
// using System.Runtime.InteropServices;

// using UnityEngine;
// using UnityEngine.XR;
// using UnityEngine.XR.Management;
// using UnityEngine.XR.ARSubsystems;

// #if UNITY_ARFOUNDATION
// using UnityEngine.XR.ARFoundation;
// #endif 

// namespace UnityEngine.XR.HoloKit
// {
//     public class DisableXRManager 
//     {
//         public  const string kHoloKitDisplayProviderId = "HoloKit-Display";
//         public  const string kHoloKitInputProviderId = "HoloKit-Input";

//         static XRDisplaySubsystemDescriptor GetHoloKitDisplaySubsystemDescriptor()
//         {
//             List<XRDisplaySubsystemDescriptor> displayProviders = new List<XRDisplaySubsystemDescriptor>();
//             SubsystemManager.GetSubsystemDescriptors(displayProviders);

//             foreach (var d in displayProviders)
//             {
//                 if (d.id.Equals(kHoloKitDisplayProviderId))
//                 {
//                     return d;
//                 }
//             }
//             return null;
//         }

//         static XRInputSubsystemDescriptor GetHoloKitInputSubsystemDescriptor()
//         {
//             List<XRInputSubsystemDescriptor> inputProviders = new List<XRInputSubsystemDescriptor>();
//             SubsystemManager.GetSubsystemDescriptors(inputProviders);

//             foreach (var d in inputProviders)
//             {
//                 if (d.id.Equals(kHoloKitInputProviderId))
//                 {
//                     return d;
//                 }
//             }
//             return null;
//         }

//         static XRSessionSubsystem GetLoadedXRSessionSubsystem()
//         {
//             List<XRSessionSubsystem> xrSessionSubsystems = new List<XRSessionSubsystem>();
//             SubsystemManager.GetSubsystems(xrSessionSubsystems);

//             foreach (var d in xrSessionSubsystems)
//             {
//                 // if (d.running) 
//                 // {
//                     Debug.Log("xrSession is founded. id" + d.subsystemDescriptor.id + "session id" + d.sessionId + "nativePtr" + d.nativePtr);
//                     return d;
// //                }
//             }
//             return null;
//         }



//         //Before AfterAssembliesLoaded
//         [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
//         static void OnSubsystemRegistration ()
//         {
//             Debug.LogWarning("OnSubsystemRegistration");
        
//             var xrSettings = XRGeneralSettings.Instance;
//             if (xrSettings == null)
//             {
//                 Debug.Log($"XRGeneralSettings is null.");
//                 return;
//             }

//             var xrManager = xrSettings.Manager;
//             if (xrManager == null)
//             {
//                 Debug.Log($"XRManagerSettings is null.");
//                 return;
//             }
//             Debug.Log($"Set automaticloading = false.");
//             xrManager.automaticLoading = false;
//          }
        
//         [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
//         static void OnAfterAssembliesLoaded() {
//            Debug.LogWarning("OnAfterAssembliesLoaded");

//         }

//         [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSplashScreen)]
//         static void OnBeforeSplashScreen() {
//            Debug.LogWarning("OnBeforeSplashScreen");

//              bool holokitDisplayStarted = false;
//             List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
//             SubsystemManager.GetSubsystems(displaySubsystems);
//             foreach (var d in displaySubsystems)
//             {
//                  Debug.Log("BeforeSplashScreen Current" + d.subsystemDescriptor.id);

//                 if (d.running)
//                 {
//                     if (!d.subsystemDescriptor.id.Equals(kHoloKitDisplayProviderId))
//                     {                        
//                        // d.Stop();
//                     }
//                     else
//                     {
//                         holokitDisplayStarted = true;
//                     }
//                 }
//             }

//             if (!holokitDisplayStarted)
//             {
//                 var holokitDisplaySubsystemDescriptor = GetHoloKitDisplaySubsystemDescriptor();
//                 // if (holokitDisplaySubsystemDescriptor != null)
//                 // {
//                 //     var holokitDisplaySubsystem = holokitDisplaySubsystemDescriptor.Create();
//                 //     if (holokitDisplaySubsystem != null)
//                 //     {
//                 //        holokitDisplaySubsystem.Start();
//                 //     }
//                 // }
//             }

//             bool holokitInputStarted = false;
//             List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
//             SubsystemManager.GetSubsystems(inputSubsystems);
//             foreach (var d in inputSubsystems)
//             {
//                 if (d.running)
//                 {
//                     if (d.subsystemDescriptor.id.Equals(kHoloKitInputProviderId))
//                     {
//                       //  holokitInputStarted = true;
//                     }
//                 }
//             }

//             if (!holokitInputStarted)
//             {
//                 var holokitInputSubsystemDescriptor = GetHoloKitInputSubsystemDescriptor();
//                 // if (holokitInputSubsystemDescriptor != null)
//                 // {
//                 //     var holokitInputSubsystem = holokitInputSubsystemDescriptor.Create();
//                 //     if (holokitInputSubsystem != null)
//                 //     {
//                 //         holokitInputSubsystem.Start();
//                 //     }
//                 // }
//             }

//             var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
//             if (xrSessionSubsystem != null) {
//                 Debug.Log("xrSessionSubsystem" + xrSessionSubsystem.sessionId + " " + xrSessionSubsystem.trackingState + " " + xrSessionSubsystem.nativePtr);
//             }
//         }
 
//         [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
//         static void OnBeforeSceneLoad() {
//             Debug.LogWarning("OnBeforeSceneLoad ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
//             var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
//             if (xrSessionSubsystem != null) {
//                 Debug.Log("xrSessionSubsystem" + xrSessionSubsystem.sessionId + " " + xrSessionSubsystem.trackingState + " " + xrSessionSubsystem.nativePtr);
//             }

//         }

//         [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
//         static void OnAfterSceneLoad() {
//             Debug.LogWarning("OnAfterSceneLoad ======> " + UnityEngine.SceneManagement.SceneManager.GetActiveScene().name + ".unity");
//             var xrSessionSubsystem = GetLoadedXRSessionSubsystem();
//             if (xrSessionSubsystem != null) {
//                 Debug.Log("xrSessionSubsystem" + xrSessionSubsystem.sessionId + " " + xrSessionSubsystem.trackingState + " " + xrSessionSubsystem.nativePtr);
//             }
//         }
//     }

//     [DisallowMultipleComponent]
//     public class HoloKitXRManager: MonoBehaviour
//     {
//         public const string kHoloKitDisplayProviderId = "HoloKit-Display";
//         public const string kHoloKitInputProviderId = "HoloKit-Input";

//         void WarnIfMultipleHoloKitXRManager()
//         {
//             var xrManagers = FindObjectsOfType<HoloKitXRManager>();
//             if (xrManagers.Length > 1)
//             {
//                 Debug.LogWarningFormat(
//                     "Multiple active AR Sessions found. " +
//                     "These will conflict with each other, so " +
//                     "you should only have one active HoloKitXRManager at a time. ");
//             }
//         }

// #if UNITY_ARFOUNDATION
        
//         static internal ARSession s_ARSession;
//         static internal IntPtr s_ARSessionNativePtr = IntPtr.Zero;

// #endif 

//         protected void Awake()
//         {
// #if UNITY_ARFOUNDATION
//             s_ARSession = GetComponent<ARSession>();
// #endif 
         
//         }


//         protected void OnEnable()
//         {
// #if DEVELOPMENT_BUILD || UNITY_EDITOR
//             WarnIfMultipleHoloKitXRManager();
// #endif
// #if UNITY_ARFOUNDATION
//              ARSession.stateChanged += OnARSessionStateChanged;
// #endif
//         }

//         protected void OnDisable()
//         {  
// #if UNITY_ARFOUNDATION
//             ARSession.stateChanged -= OnARSessionStateChanged;
// #endif
//         }
// #if UNITY_ARFOUNDATION
//         void OnARSessionStateChanged(ARSessionStateChangedEventArgs args) {
//             if (args.state == ARSessionState.SessionTracking) {
                
//                 if (s_ARSessionNativePtr == IntPtr.Zero && s_ARSession.subsystem != null) {
//                     s_ARSessionNativePtr = s_ARSession.subsystem.nativePtr;
//                     if (s_ARSessionNativePtr != IntPtr.Zero) {
//                         UnityHoloKit_SetARSession(s_ARSessionNativePtr);
//                         Debug.Log("ArSession Setted");
//                     }
//                 }
//             } else {
//                 if (s_ARSessionNativePtr != IntPtr.Zero) {
//                     s_ARSessionNativePtr = IntPtr.Zero;
//                     UnityHoloKit_SetARSession(IntPtr.Zero);
//                 }
//             }
//         }
// #endif

//         [DllImport("__Internal")]
//         public static extern void UnityHoloKit_SetARSession(IntPtr ptr);
//     }
// }
