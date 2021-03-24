using System.Collections.Generic;
using UnityEngine.Experimental.XR;
using UnityEngine.XR;
using UnityEngine.XR.Management;
using UnityEngine;

namespace Unity.XR.HoloKit
{
	public class HoloKitDisplayXRLoader : XRLoaderHelper
	{
		private static List<XRDisplaySubsystemDescriptor> s_DisplaySubsystemDescriptors =
            new List<XRDisplaySubsystemDescriptor>();
        

        public override bool Initialize()
        {
            UnityEngine.Debug.Log("going to create display0");
            CreateSubsystem<XRDisplaySubsystemDescriptor, XRDisplaySubsystem>(s_DisplaySubsystemDescriptors, "display0");
            Debug.Log("HoloKit SDK display0 subsystem is created.");
            //CreateSubsystem<XRInputSubsystemDescriptor, XRInputSubsystem>(s_InputSubsystemDescriptors, "Head Tracking Sample");
            return true;
        }

        public override bool Start()
        {
            StartSubsystem<XRDisplaySubsystem>();
           // StartSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Stop()
        {
            StopSubsystem<XRDisplaySubsystem>();
            //StopSubsystem<XRInputSubsystem>();
            return true;
        }

        public override bool Deinitialize()
        {
            DestroySubsystem<XRDisplaySubsystem>();
            //DestroySubsystem<XRInputSubsystem>();
            return true;
        }
	}
}