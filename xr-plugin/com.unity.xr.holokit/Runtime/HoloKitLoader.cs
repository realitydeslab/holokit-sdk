using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;

using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.ARSubsystems;
using UnityEngine.XR.Management;

using XRGestureSubsystem = UnityEngine.XR.InteractionSubsystems.XRGestureSubsystem;
using XRGestureSubsystemDescriptor = UnityEngine.XR.InteractionSubsystems.XRGestureSubsystemDescriptor;

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
                    .WithProduct(@"(^(Hand -))")
            );
        }
    }
#endif

//     public class HoloKitLoader : XRLoaderHelper
//     {
//         private static List<XRDisplaySubsystemDescriptor> s_DisplaySubsystemDescriptors = new List<XRDisplaySubsystemDescriptor>();
//         private static List<XRInputSubsystemDescriptor> s_InputSubsystemDescriptors = new List<XRInputSubsystemDescriptor>();

//         public XRDisplaySubsystem displaySubsystem => GetLoadedSubsystem<XRDisplaySubsystem>();
//         public XRInputSubsystem inputSubsystem => GetLoadedSubsystem<XRInputSubsystem>();

//         public override bool Initialize() 
//         {
// #if UNITY_INPUT_SYSTEM
//             InputLayoutLoader.RegisterInputLayouts();
// #endif
//             CreateSubsystem<XRDisplaySubsystemDescriptor, XRDisplaySubsystem>(s_DisplaySubsystemDescriptors, "HoloKit-Display");
//             CreateSubsystem<XRInputSubsystemDescriptor, XRInputSubsystem>(s_InputSubsystemDescriptors, "HoloKit-Input");
            
//             return displaySubsystem != null && inputSubsystem != null;
//         }

//         public override bool Start()
//         {
//             StartSubsystem<XRDisplaySubsystem>();
//             StartSubsystem<XRInputSubsystem>();
//             return true;
//         }

//         public override bool Stop()
//         {
//             StopSubsystem<XRDisplaySubsystem>();
//             StopSubsystem<XRInputSubsystem>();
//             return true;
//         }

//         public override bool Deinitialize()
//         {
//             DestroySubsystem<XRDisplaySubsystem>();
//             DestroySubsystem<XRInputSubsystem>();
//             return true;
//         }
//     }
}
