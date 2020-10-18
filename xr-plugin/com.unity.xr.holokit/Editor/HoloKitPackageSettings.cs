using System;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.XR.Management;

using UnityEditor;

using UnityEngine.XR.HoloKit;

namespace UnityEditor.XR.HoloKit
{
    [System.Serializable]
    [XRConfigurationData("HoloKit", "UnityEditor.XR.HoloKit.HoloKitPackageSettings")]
    public class HoloKitPackageSettings : ScriptableObject
    {
        public enum Requirement
        {
            /// <summary>
            /// HoloKit is required, which means the app cannot be installed on devices that do not support HoloKit.
            /// </summary>
            Required,

            /// <summary>
            /// HoloKit is optional, which means the the app can be installed on devices that do not support HoloKit.
            /// </summary>
            Optional
        }

        [SerializeField, Tooltip("Toggles whether HoloKit is required for this app. Will make app only downloadable by devices with HoloKit support if set to 'Required'.")]
        Requirement m_Requirement;
    }
}