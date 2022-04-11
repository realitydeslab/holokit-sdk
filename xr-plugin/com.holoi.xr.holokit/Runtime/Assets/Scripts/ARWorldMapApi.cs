using System.Runtime.InteropServices;
using System;
using System.IO;

namespace UnityEngine.XR.HoloKit
{
    public enum ARWorldMappingStatus
    {
        ARWorldMappingStatusNotAvailable = 0,
        ARWorldMappingStatusLimited = 1,
        ARWorldMappingStatusExtending = 2,
        ARWorldMappingStatusMapped = 3
    }

    public static class ARWorldMapApi
    {
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetScanEnvironment(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARWorldMappingStatusDidChangeDelegate(Action<int> status);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SaveARWorldMap(string mapName);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidSaveARWorldMapDelegate(Action<string> callback);

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_RetrieveARWorldMap(string mapName);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_LoadARWorldMap();

        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnARWorldMappingStatusDidChange(int status)
        {
            //Debug.Log($"[ARWorldMapApi] OnARWorldMappingStatusDidChange {(ARWorldMappingStatus)status}");
            ARWorldMappingStatusDidChangeEvent?.Invoke((ARWorldMappingStatus)status);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<string>))]
        private static void OnDidSaveARWorldMap(string mapName)
        {
            DidSaveARWorldMapEvent?.Invoke(mapName);
        }

        public static event Action<ARWorldMappingStatus> ARWorldMappingStatusDidChangeEvent;

        public static event Action<string> DidSaveARWorldMapEvent;

        public static void StartScanEnvironment()
        {
            Debug.Log("[ARWorldMap] StartScanEnvironment");
            UnityHoloKit_SetARWorldMappingStatusDidChangeDelegate(OnARWorldMappingStatusDidChange);
            UnityHoloKit_SetDidSaveARWorldMapDelegate(OnDidSaveARWorldMap);
            UnityHoloKit_SetScanEnvironment(true);
        }

        public static void StopScanEnvironment()
        {
            UnityHoloKit_SetARWorldMappingStatusDidChangeDelegate(null);
            UnityHoloKit_SetDidSaveARWorldMapDelegate(null);
            UnityHoloKit_SetScanEnvironment(false);
        }

        public static void SaveARWorldMap()
        {
            // Generate map name
            string mapName = DateTime.Now.ToString("yyyy-MM-ddTHH-mm-ss");
            TakeScreenshot(mapName);
            UnityHoloKit_SaveARWorldMap(mapName);
        }

        // Returns the file path of ARWorldMap files in local storage.
        public static string[] QueryARWorldMapFileList()
        {
            string folder = Application.persistentDataPath + "/Maps/";
            if (Directory.Exists(folder))
            {
                string[] files = Directory.GetFiles(folder);
                return files;
            }
            return null;
        }

        private static void TakeScreenshot(string mapName)
        {
            string directoryPath = Application.persistentDataPath + "/MapScreenshots/";
            if (!Directory.Exists(directoryPath))
                Directory.CreateDirectory(directoryPath);

            string filePath = "/MapScreenshots/" + mapName + ".png";
            ScreenCapture.CaptureScreenshot(filePath);
        }

        public static Sprite GetMapScreenshot(string mapName)
        {
            string imagePath = Application.persistentDataPath + $"/MapScreenshots/{mapName}.png";
            if (File.Exists(imagePath))
            {
                byte[] imageData = File.ReadAllBytes(imagePath);
                Texture2D tex = new(100, 100);
                tex.LoadImage(imageData); // This will auto-resize the texture dimensions.
                //Debug.Log($"[ARWorldMap] screenshot width {tex.width} and height {tex.height}");
                return Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f), 100);
            }
            return null;
        }

        public static void DeleteAllMaps()
        {
            string mapPath = Application.persistentDataPath + "/Maps/";
            string screenshotPath = Application.persistentDataPath + "/MapScreenshots/";
            if (Directory.Exists(mapPath))
            {
                string[] mapFiles = Directory.GetFiles(mapPath);
                foreach (var mapFile in mapFiles)
                {
                    File.Delete(mapFile);
                    Debug.Log($"[ARWorldMapApi] deleted map: {mapFile}");
                }
            }
            if (Directory.Exists(screenshotPath))
            {
                string[] screenshotFiles = Directory.GetFiles(screenshotPath);
                foreach (var screenshotFile in screenshotFiles)
                {
                    File.Delete(screenshotFile);
                    Debug.Log($"[ARWorldMapApi] deleted screenshot: {screenshotFile}");
                }
            }
        }

        public static bool RetrieveARWorldMap(string mapName)
        {
            return UnityHoloKit_RetrieveARWorldMap(mapName);
        }

        public static void LoadARWorldMap()
        {
            Debug.Log("[ARWorldMap] LoadARWorldMap");
            UnityHoloKit_LoadARWorldMap();
        }
    }
}
