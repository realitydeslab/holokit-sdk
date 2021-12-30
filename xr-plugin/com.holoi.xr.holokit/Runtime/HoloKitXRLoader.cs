using System.Collections.Generic;
using UnityEngine.XR.Management;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitXRLoader : XRLoaderHelper
    {
        private static List<XRDisplaySubsystemDescriptor> s_DisplaySubsystemDescriptors = new List<XRDisplaySubsystemDescriptor>();
        private static List<XRInputSubsystemDescriptor> s_InputSubsystemDescriptors = new List<XRInputSubsystemDescriptor>();

        public override bool Initialize() 
        {
            Debug.Log("[HoloKitXRLoader] Initialize");
            CreateSubsystem<XRDisplaySubsystemDescriptor, XRDisplaySubsystem>(s_DisplaySubsystemDescriptors, "HoloKit Display");
            CreateSubsystem<XRInputSubsystemDescriptor, XRInputSubsystem>(s_InputSubsystemDescriptors, "HoloKit Input");
            return true;
        }

        public override bool Start()
        {
            Debug.Log("[HoloKitXRLoader] Start");
            StartSubsystem<XRDisplaySubsystem>();
            StartSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Stop()
        {
            Debug.Log("[HoloKitXRLoader] Stop");
            StopSubsystem<XRDisplaySubsystem>();
            StopSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Deinitialize()
        {
            Debug.Log("[HoloKitXRLoader] Deinitialize");
            DestroySubsystem<XRDisplaySubsystem>();
            DestroySubsystem<XRInputSubsystem>();
            return true;
        }
    }
}
