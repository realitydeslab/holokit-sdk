using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.ARFoundation;
using Holoi.HoloKit.NativeInterface;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit
{
    public class HoloKitDriver : MonoBehaviour
    {
        [SerializeField] private SceneField[] _arScenes;

        private void Awake()
        {
            // Check whether the current device is supported by HoloKit
            if (!HoloKitDeviceProfile.IsSupported())
            {
                Debug.Log("[HoloKitSDK] The current device is not supported by HoloKit");
                return;
            }

            DontDestroyOnLoad(gameObject);
            if (PlatformChecker.IsRuntime)
            {
                HoloKitARSessionManagerNativeInterface.RegisterARSessionDelegates();
                HoloKitARSessionManagerNativeInterface.InterceptUnityARSessionDelegates();

                HoloKitIOSManagerNativeInterface.RegisterIOSNativeDelegates();
                HoloKitHandTrackerNativeInterface.RegisterHandTrackerDelegates();
            }
            SceneManager.sceneUnloaded += OnSceneUnloaded;
        }

        private void OnDestroy()
        {
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
        }

        private void OnSceneUnloaded(Scene scene)
        {
            foreach (var arScene in _arScenes)
            {
                if (scene.name.Equals(arScene.SceneName))
                {
                    LoaderUtility.Deinitialize();
                    LoaderUtility.Initialize();
                    HoloKitARSessionManagerNativeInterface.InterceptUnityARSessionDelegates();
                    return;
                }
            }
        }
    }
}
