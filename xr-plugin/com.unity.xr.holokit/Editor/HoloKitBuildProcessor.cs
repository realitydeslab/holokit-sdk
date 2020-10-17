namespace UnityEditor.XR.HoloKit
{
    using System.Collections.Generic;
    using System.IO;
    using UnityEditor;
    using UnityEditor.Callbacks;
    using UnityEditor.iOS.Xcode;
    using UnityEngine;

    /// <summary>Processes the project files after the build is performed.</summary>
    class HoloKitBuildProcessor
    {
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

