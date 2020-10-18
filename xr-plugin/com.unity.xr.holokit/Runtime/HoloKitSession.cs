// using System;
// using System.Collections;
// using System.Collections.Generic;
// using System.Reflection;
// using System.Runtime.CompilerServices;
// using System.Runtime.InteropServices;

// using UnityEngine;
// using UnityEngine.XR;
// using UnityEngine.XR.ARFoundation;

// namespace HoloKit
// {

//     internal static class ARSessionExtensions
//     {
//         public static IntPtr SessionHandle(this ARSession session)
//         {
//             if (session.subsystem == null || session.subsystem.nativePtr == null)
//             {
//                 return IntPtr.Zero;
//             }

//             NativePointerStruct info = (NativePointerStruct)
//                 Marshal.PtrToStructure(
//                     session.subsystem.nativePtr,
//                     typeof(NativePointerStruct));

//             return info.SessionHandle;
//         }

//         [StructLayout(LayoutKind.Sequential)]
//         public struct NativePointerStruct
//         {
//             public int Version;
//             public IntPtr SessionHandle;
//         }
//     }



    
//     [DisallowMultipleComponent]
//     [RequireComponent(typeof(ARSession))]
//     public class HoloKitSession: MonoBehaviour
//     {
//         static internal ARSession s_ARSession;
//         static internal IntPtr s_ARSessionNativePtr = IntPtr.Zero;

//         protected void Awake()
//         {
//             s_ARSession = GetComponent<ARSession>();
//         }

//         protected void OnEnable()
//         {
// #if DEVELOPMENT_BUILD || UNITY_EDITOR
//             WarnIfMultipleHoloKitSessions();
// #endif
//             ARSession.stateChanged += OnARSessionStateChanged;
//         }

//         protected void OnDisable()
//         {  
//             ARSession.stateChanged -= OnARSessionStateChanged;
//         }

//         void OnARSessionStateChanged(ARSessionStateChangedEventArgs args) {
//             if (args.state == ARSessionState.SessionTracking) {
//                 if (s_ARSessionNativePtr == IntPtr.Zero && s_ARSession.subsystem != null) {
//                     s_ARSessionNativePtr = s_ARSession.SessionHandle();
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

//         [DllImport("__Internal")]
//         public static extern void UnityHoloKit_SetARSession(IntPtr ptr);

//         void WarnIfMultipleHoloKitSessions()
//         {
//             var sessions = FindObjectsOfType<HoloKitSession>();
//             if (sessions.Length > 1)
//             {
//                 // Compile a list of session names
//                 string sessionNames = "";
//                 foreach (var session in sessions)
//                 {
//                     sessionNames += string.Format("\t{0}\n", session.name);
//                 }

//                 Debug.LogWarningFormat(
//                     "Multiple active AR Sessions found. " +
//                     "These will conflict with each other, so " +
//                     "you should only have one active HoloKitSession at a time. " +
//                     "Found these active sessions:\n{0}", sessionNames);
//             }
//         }
//     }
// }
