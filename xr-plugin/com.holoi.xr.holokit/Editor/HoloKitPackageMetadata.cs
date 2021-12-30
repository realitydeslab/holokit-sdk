using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using UnityEngine;

using UnityEditor;
using UnityEditor.XR.Management;
using UnityEditor.XR.Management.Metadata;

using UnityEngine.XR.HoloKit;

namespace UnityEditor.XR.HoloKit
{
    public class XRPackage : IXRPackage
    {
        private class LoaderMetadata : IXRLoaderMetadata
        {
            public string loaderName { get; set; }
            public string loaderType { get; set; }
            public List<BuildTargetGroup> supportedBuildTargets { get; set; }
        }

        private class PackageMetadata : IXRPackageMetadata
        {
            public string packageName { get; set; }
            public string packageId { get; set; }
            public string settingsType { get; set; }
            public List<IXRLoaderMetadata> loaderMetadata { get; set; } 
        }
        
         private static IXRPackageMetadata s_Metadata = new PackageMetadata(){
                packageName = "HoloKit XR Plugin",
                packageId = "com.holoi.xr.holokit",
                // should be "HoloKitPackageSettings"
                settingsType = typeof(HoloKitXRLoader).FullName,
                loaderMetadata = new List<IXRLoaderMetadata>() {
                    new LoaderMetadata() {
                        loaderName = "HoloKit",
                        loaderType = typeof(HoloKitXRLoader).FullName,
                        supportedBuildTargets = new List<BuildTargetGroup>() {
                            BuildTargetGroup.iOS, 
                            BuildTargetGroup.Standalone //TODO(for dummy test)
                        }
                    },
                }
            };

        // private static IXRPackageMetadata s_Metadata = new PackageMetadata(){
        //     packageName = "HoloKit XR Plugin",
        //     packageId = "com.unity.xr.holokit",
        //     settingsType = typeof(HoloKitPackageSettings).FullName,
        //     loaderMetadata = new List<IXRLoaderMetadata>() {
        //     }
        // };
        public IXRPackageMetadata metadata => s_Metadata;

        public bool PopulateNewSettingsInstance(ScriptableObject obj)
        {
            return true;
        }
    }
}
