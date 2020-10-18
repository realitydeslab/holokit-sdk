using System.Collections.Generic;
using System;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;

namespace UnityEditor.XR.HoloKit
{

    /// <summary>Processes the project files after the build is performed.</summary>
    class HoloKitBuildProcessor
    {
        //    #if UNITY_IOS
        //        using UnityEditor.iOS;
        //        using UnityEngine.XR.ARKit;

        //    class BuildPreprocessor : IPreprocessBuildWithReport
        //    {
        //        static readonly OSVersion k_MinimumXcodeTargetVersion = new OSVersion(14, 0, 0);

        //        public void OnPreprocessBuild(BuildReport report)
        //        {
        //            if (report.summary.platform == BuildTarget.iOS)
        //            {
        //                EnsureMinimumXcodeVersion();
        //            }
        //        }

        //        void EnsureMinimumXcodeVersion()
        //        {
        //#if UNITY_EDITOR_OSX
        //            var xcodeIndex = Math.Max(0, XcodeApplications.GetPreferedXcodeIndex());
        //            var xcodeVersion = OSVersion.Parse(XcodeApplications.GetXcodeApplicationPublicName(xcodeIndex));
        //            if (xcodeVersion == new OSVersion(0))
        //                throw new BuildFailedException($"Could not determine which version of Xcode was selected in the Build Settings. Xcode app was computed as \"{XcodeApplications.GetXcodeApplicationPublicName(xcodeIndex)}\".");

        //            if (xcodeVersion < new OSVersion(12, 0, 0))
        //                throw new BuildFailedException($"The selected Xcode version: {xcodeVersion} is below the minimum Xcode required Xcode version for the Unity ARKit Face Tracking Plugin.  Please target at least Xcode version {k_MinimumXcodeTargetVersion}.");
        //#endif
        //        }

        //        public int callbackOrder => 0;
        //    }
        //    #endif



        //     class PostProcessor : IPostprocessBuildWithReport 
        //     {
        //         public int callbackOrder => 1;

        //         void PostprocessBuild(BuildReport report)
        //         {
        //             if (report.summary.platform != BuildTarget.iOS)
        //             {
        //                 return;
        //             }

        //             string projectPath = PBXProject.GetPBXProjectPath(path);
        //             string projectConfig = File.ReadAllText(projectPath);
        //             projectConfig = projectConfig.Replace("ENABLE_BITCODE = YES",
        //                                                   "ENABLE_BITCODE = NO");
        //             File.WriteAllText(projectPath, projectConfig);
        //         }

        //     }

        //     class 

        //      IPreprocessBuildWithReport, IPostprocessBuildWithReport

        //     public int callbackOrder => 1;

        //     /// <summary>Unity callback to process after build.</summary>
        //     /// <param name="buildTarget">Target built.</param>
        //     /// <param name="path">Path to built project.</param>
        //     [PostProcessBuild]
        //     public static void OnPostProcessBuild(BuildTarget buildTarget, string path)
        //     {
        //         // If we are building for iOS, we need to disable EmbedBitcode support.
        //         if (buildTarget == BuildTarget.iOS)
        //         {
        //             string projectPath = PBXProject.GetPBXProjectPath(path);
        //             string projectConfig = File.ReadAllText(projectPath);
        //             projectConfig = projectConfig.Replace("ENABLE_BITCODE = YES",
        //                                                   "ENABLE_BITCODE = NO");
        //             File.WriteAllText(projectPath, projectConfig);
        //         }
        //     }
        // }
    }
}

