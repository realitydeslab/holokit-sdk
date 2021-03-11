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
            CreateSubsystem<XRInputSubsystemDescriptor, XRInputSubsystem>(s_InputSubsystemDescriptors, "input0");
            Debug.Log("Input Subsystem input0 is created.");
            return true;
        }

        public override bool Start()
        {
            StartSubsystem<XRInputSubsystem>();
            //Debug.Log("XRLoader::Start()");
            return true;
        }

        public override bool Stop()
        {
            StopSubsystem<XRInputSubsystem>();
            //Debug.Log("XRLoader::Stop()");
            return true;
        }

        public override bool Deinitialize()
        {
            DestroySubsystem<XRInputSubsystem>();
            //Debug.Log("XRLoader::Deinitialize()");
            return true;
        }
    }
}
