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

        [SerializeField] private bool _sessionShouldAttemptRelocalization = false;

        private void Awake()
        {
            DontDestroyOnLoad(gameObject);
            if (PlatformChecker.IsRuntime)
            {
                HoloKitARSessionManagerNativeInterface.RegisterARSessionDelegates();
                HoloKitARSessionManagerNativeInterface.SetSessionShouldAttemptRelocalization(_sessionShouldAttemptRelocalization);
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
