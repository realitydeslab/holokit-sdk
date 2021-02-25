using System.Collections.Generic;
using UnityEngine.XR;
using UnityEngine.XR.Management;
using UnityEngine;

namespace Unity.XR.SDK
{
    public class InputSampleXRLoader : XRLoaderHelper
    {
        private static List<XRInputSubsystemDescriptor> s_InputSubsystemDescriptors =
            new List<XRInputSubsystemDescriptor>();

        public override bool Initialize()
        {
            //Debug.Log("dddddddddddd");
            CreateSubsystem<XRInputSubsystemDescriptor, XRInputSubsystem>(s_InputSubsystemDescriptors, "input0");
            return true;
        }

        public override bool Start()
        {
            StartSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Stop()
        {
            StopSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Deinitialize()
        {
            DestroySubsystem<XRInputSubsystem>();
            return true;
        }
    }
}
