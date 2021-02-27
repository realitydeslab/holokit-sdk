using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using UnityEngine;

using UnityEditor;
using UnityEditor.XR.Management;
using UnityEditor.XR.Management.Metadata;


namespace Unity.XR.SDK
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
                packageName = "inputsample XR Plugin",
                packageId = "com.unity.xr.sdk.inputsample",
                settingsType = typeof(InputSampleXRLoader).FullName,
                loaderMetadata = new List<IXRLoaderMetadata>() {
                    new LoaderMetadata() {
                        loaderName = "inputsample",
                        loaderType = typeof(InputSampleXRLoader).FullName,
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
