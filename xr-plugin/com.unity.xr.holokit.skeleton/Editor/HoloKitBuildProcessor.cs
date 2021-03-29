#if UNITY_IOS
/*
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEditor.iOS.Xcode.Extensions;
using UnityEditor.iOS;
using UnityEngine.XR.ARKit;
using OSVersion = UnityEngine.XR.ARKit.OSVersion;

namespace UnityEditor.XR.HoloKit
{

    /// <summary>Processes the project files after the build is performed.</summary>
    class HoloKitBuildProcessor
    {

        class BuildPreprocessor : IPreprocessBuildWithReport
        {
            // The minimum target Xcode version for the plugin
            const int k_TargetMinimumMajorXcodeVersion = 12;
            const int k_TargetMinimumMinorXcodeVersion = 0;
            const int k_TargetMinimumPatchXcodeVersion = 0;

            static readonly OSVersion k_MinimumiOSTargetVersion = new OSVersion(14, 0, 0);

            public void OnPreprocessBuild(BuildReport report)
            {
                if (report.summary.platform != BuildTarget.iOS)
                    return;

                EnsureMinimumXcodeVersion();
                EnsureMinimumBuildTarget();
            }

            void EnsureMinimumBuildTarget()
            {
                var userSetTargetVersion = OSVersion.Parse(PlayerSettings.iOS.targetOSVersionString);
                if (userSetTargetVersion < k_MinimumiOSTargetVersion)
                {
                    throw new BuildFailedException($"You have selected a minimum target iOS version of {userSetTargetVersion} and have the HoloKit package installed."
                        + "HoloKit requires at least iOS version 14.0 (See Player Settings > Other Settings > Target minimum iOS Version).");
                }
            }

            void EnsureMinimumXcodeVersion()
            {
#if UNITY_EDITOR_OSX
                var xcodeIndex = Math.Max(0, XcodeApplications.GetPreferedXcodeIndex());
                var xcodeVersion = OSVersion.Parse(XcodeApplications.GetXcodeApplicationPublicName(xcodeIndex));
                if (xcodeVersion == new OSVersion(0))
                    throw new BuildFailedException($"Could not determine which version of Xcode was selected in the Build Settings. Xcode app was computed as \"{XcodeApplications.GetXcodeApplicationPublicName(xcodeIndex)}\".");

                if (xcodeVersion < new OSVersion(
                    k_TargetMinimumMajorXcodeVersion,
                    k_TargetMinimumMinorXcodeVersion,
                    k_TargetMinimumPatchXcodeVersion))
                    throw new BuildFailedException($"The selected Xcode version: {xcodeVersion} is below the minimum Xcode required Xcode version for the Unity ARKit Plugin.  Please target at least Xcode version {k_TargetMinimumMajorXcodeVersion}.{k_TargetMinimumMinorXcodeVersion}.{k_TargetMinimumPatchXcodeVersion}.");
#endif
            }

            public int callbackOrder => 0;
        }


        class PostProcessor : IPostprocessBuildWithReport
        {
            // NB: Needs to be > 0 to make sure we remove the shader since the
            //     Input System overwrites the preloaded assets array
            public int callbackOrder => 1;

            void PostprocessBuild(BuildReport report)
            {
                if (report.summary.platform != BuildTarget.iOS)
                {
                    return;
                }

                AddDynamicFramework(report.summary.outputPath);
            }

            public void OnPostprocessBuild(BuildReport report)
            {
                PostprocessBuild(report);
            }

            static void AddDynamicFramework(string pathToBuiltProject)
            {
                string projPath = PBXProject.GetPBXProjectPath(pathToBuiltProject);
                PBXProject proj = new PBXProject();
                proj.ReadFromString(File.ReadAllText(projPath));

                string mainTargetGuid = proj.GetUnityMainTargetGuid();
                string unityFrameworkTargetGuid = proj.GetUnityFrameworkTargetGuid();

                proj.SetBuildProperty(mainTargetGuid, "ENABLE_BITCODE", "NO");
                proj.SetBuildProperty(unityFrameworkTargetGuid, "ENABLE_BITCODE", "NO");

               // string framework = "com.unity.xr.holokit/Runtime/ios/arm64/HandTracker.framework";
               // string fileGuid = proj.AddFile(framework, "Frameworks/" + framework, PBXSourceTree.Source);
           
           //     PBXProjectExtensions.AddFileToEmbedFrameworks(proj, mainTargetGuid, fileGuid);
                // proj.SetBuildProperty(unityFrameworkTargetGuid, "LD_RUNPATH_SEARCH_PATHS", "$(inherited) @executable_path/Frameworks");
                // proj.SetBuildProperty(mainTargetGuid, "LD_RUNPATH_SEARCH_PATHS", "$(inherited) @executable_path/Frameworks");

                proj.WriteToFile(projPath);
            }
        }


    }
}
*/
#endif