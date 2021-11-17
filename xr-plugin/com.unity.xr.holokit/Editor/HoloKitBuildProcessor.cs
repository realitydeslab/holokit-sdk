#if UNITY_IOS

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEditor.iOS.Xcode.Extensions;
using UnityEditor.iOS;
using UnityEditor.Callbacks;
using UnityEngine;
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

            public void OnPostprocessBuild(BuildReport report)
            {
                PostprocessBuild(report);
            }

            void PostprocessBuild(BuildReport report)
            {
                if (report.summary.platform != BuildTarget.iOS)
                {
                    return;
                }

                ChangeXcodePlist(report.summary.outputPath);
                AddXcodeCapabilities(report.summary.outputPath);
                AddDynamicFramework(report.summary.outputPath);
                //AppleWatchSetup(report.summary.outputPath);
            }

            static void ChangeXcodePlist(string path) 
            {
                string plistPath = path + "/Info.plist";
                PlistDocument plist = new PlistDocument();
                plist.ReadFromFile(plistPath);

                PlistElementDict rootDict = plist.root;

                Debug.Log("[HoloKitBuildProcessor]: ChangeXcodePlist()");

                // For NFC
                rootDict.SetString("NFCReaderUsageDescription", "For HoloKit to authenticate the NFC chip.");

                // For AR collaboration
                rootDict.SetString("NSLocalNetworkUsageDescription", "For HoloKit to enable nearby AR collaboration.");
                PlistElementArray array = rootDict.CreateArray("NSBonjourServices");
                array.AddString("_holokit-collab._tcp");
                array.AddString("_holokit-collab._udp");

                // For CoreLocation
                rootDict.SetString("NSLocationWhenInUseUsageDescription", "For thatReality to locate your current location.");

                // For save replay to iPhone's photo library
                rootDict.SetString("NSPhotoLibraryAddUsageDescription", "Export AR replay.");
                rootDict.SetString("NSPhotoLibraryUsageDescription", "Export AR replay.");

                // For speech recognition
                rootDict.SetString("NSSpeechRecognitionUsageDescription", "HoloKit uses speech recognition to cast spell.");

                File.WriteAllText(plistPath, plist.WriteToString());
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

                string framework = "com.unity.xr.holokit/Runtime/ios/arm64/HandTracker.framework";
                string fileGuid = proj.AddFile(framework, "Frameworks/" + framework, PBXSourceTree.Source);
           
                PBXProjectExtensions.AddFileToEmbedFrameworks(proj, mainTargetGuid, fileGuid);
                proj.SetBuildProperty(unityFrameworkTargetGuid, "LD_RUNPATH_SEARCH_PATHS", "$(inherited) @executable_path/Frameworks");
                proj.SetBuildProperty(mainTargetGuid, "LD_RUNPATH_SEARCH_PATHS", "$(inherited) @executable_path/Frameworks");

                proj.WriteToFile(projPath);
            }

            private static void AddXcodeCapabilities(string buildPath)
            {
                string projectPath = PBXProject.GetPBXProjectPath(buildPath);
                PBXProject project = new PBXProject();
                project.ReadFromFile(projectPath);
                string target = project.GetUnityMainTargetGuid();

                string packageName = UnityEngine.Application.identifier;
                string name = packageName.Substring(packageName.LastIndexOf('.') + 1);
                string entitlementFileName = name + ".entitlements";
                string entitlementPath = Path.Combine(buildPath, entitlementFileName);
                ProjectCapabilityManager projectCapabilityManager = new ProjectCapabilityManager(projectPath, entitlementFileName, null, target);
                PlistDocument entitlementDocument = AddNFCEntitlement(projectCapabilityManager);
                entitlementDocument.WriteToFile(entitlementPath);

                var projectInfo = projectCapabilityManager.GetType().GetField("project", BindingFlags.NonPublic | BindingFlags.Instance);
                project = (PBXProject)projectInfo.GetValue(projectCapabilityManager);

                var constructor = typeof(PBXCapabilityType).GetConstructor(BindingFlags.NonPublic | BindingFlags.Instance, null, new Type[] { typeof(string), typeof(bool), typeof(string), typeof(bool) }, null);
                PBXCapabilityType nfcCapability = (PBXCapabilityType)constructor.Invoke(new object[] { "com.apple.NearFieldCommunicationTagReading", true, "", false });
                project.AddCapability(target, nfcCapability, entitlementFileName);

                projectCapabilityManager.AddSignInWithApple();

                projectCapabilityManager.WriteToFile();
            }

            private static PlistDocument AddNFCEntitlement(ProjectCapabilityManager projectCapabilityManager)
            {
                MethodInfo getMethod = projectCapabilityManager.GetType().GetMethod("GetOrCreateEntitlementDoc", BindingFlags.NonPublic | BindingFlags.Instance);
                PlistDocument entitlementDoc = (PlistDocument)getMethod.Invoke(projectCapabilityManager, new object[] { });

                PlistElementDict dictionary = entitlementDoc.root;
                PlistElementArray array = dictionary.CreateArray("com.apple.developer.nfc.readersession.formats");
                array.values.Add(new PlistElementString("NDEF"));
                array.values.Add(new PlistElementString("TAG"));

                return entitlementDoc;
            }

            // https://github.com/Manurocker95/IronRuby-Test/blob/57f8b66e88d7df2e9bd7936e83777a79427f8e13/Assets/VirtualPhenix/Scripts/Editor/AppleWatch/VP_SetupWatchExtension.cs
            private static void AppleWatchSetup(string buildPath)
            {
                PBXProject project = new PBXProject();
                string projectPath = PBXProject.GetPBXProjectPath(buildPath);
                project.ReadFromFile(projectPath);
                string targetGuid = project.GetUnityFrameworkTargetGuid();

                string packageName = UnityEngine.Application.identifier;

                string watchExtensionTargetGuid = PBXProjectExtensions.AddWatchExtension(project, targetGuid,
                    "Watch Extension",
                    $"{packageName}.watchkitapp.watchkitextension",
                    "Watch Extension/Info.plist");

                string watchAppTargetGuid = PBXProjectExtensions.AddWatchApp(project, targetGuid, watchExtensionTargetGuid,
                    "Watch",
                    $"{packageName}.watchkitapp",
                    "Watch/Info.plist");

                FileUtil.CopyFileOrDirectory("Assets/Plugins/AppleWatchAsController/Watch", Path.Combine(buildPath, "Watch"));
                FileUtil.CopyFileOrDirectory("Assets/Plugins/AppleWatchAsController/Watch Extension", Path.Combine(buildPath, "Watch Extension"));

                var filesToBuild = new List<string>
                {
                    "Watch/Interface.storyboard",
                    "Watch/Assets.xcassets"
                };

                foreach(var path in filesToBuild)
                {
                    var fileGuid = project.AddFile(path, path);
                    project.AddFileToBuild(watchAppTargetGuid, fileGuid);
                }

                filesToBuild = new List<string>
                {
                    "Watch Extension/Assets.xcassets",
                    "Watch Extension/ExtensionDelegate.swift",
                    "Watch Extension/InterfaceController.swift",
                    "Watch Extension/NotificationController.swift",
                    "Watch Extension/ComplicationController.swift",
                };

                foreach (var path in filesToBuild)
                {
                    var fileGuid = project.AddFile(path, path);
                    project.AddFileToBuild(watchExtensionTargetGuid, fileGuid);
                }

                var filesToAdd = new List<string>
                {
                    "Watch/Info.plist",
                    "Watch Extension/Info.plist",
                    "Watch Extension/PushNotificationPayload.apns"
                };

                foreach (var path in filesToAdd)
                {
                    project.AddFile(path, path);
                }

                project.SetBuildProperty(watchAppTargetGuid, "SWIFT_VERSION", "5.0");
                project.SetBuildProperty(watchExtensionTargetGuid, "SWIFT_VERSION", "5.0");

                foreach (var configName in project.BuildConfigNames())
                {
                    var configGuid = project.BuildConfigByName(watchAppTargetGuid, configName);

                    project.SetBuildPropertyForConfig(configGuid, "WATCHOS_DEPLOYMENT_TARGET", "8.0");
                }


                foreach (var configName in project.BuildConfigNames())
                {
                    var configGuid = project.BuildConfigByName(watchExtensionTargetGuid, configName);

                    project.SetBuildPropertyForConfig(configGuid, "WATCHOS_DEPLOYMENT_TARGET", "8.0");
                }

                project.WriteToFile(projectPath);
            }
        }


    }
}

#endif