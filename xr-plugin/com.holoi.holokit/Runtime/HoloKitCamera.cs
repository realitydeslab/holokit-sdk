using System;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.InputSystem.XR;
using Holoi.HoloKit.NativeInterface;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit
{
    public enum HoloKitRenderMode
    {
        Mono = 0,
        Stereo = 1
    }

    public class HoloKitCamera : MonoBehaviour
    {
        public static HoloKitCamera Instance { get { return _instance; } }

        private static HoloKitCamera _instance;

        [SerializeField] private Transform _centerEyePose;

        [SerializeField] private Camera _monoCamera;

        [SerializeField] private Camera _leftEyeCamera;

        [SerializeField] private Camera _rightEyeCamera;

        [SerializeField] private Camera _blackCamera;

        [SerializeField]
        [Range(0.054f, 0.074f)]
        private float _ipd = 0.064f;

        [SerializeField] private float _farClipPlane = 50f;

        [SerializeField] private BackgroundVideoFormat _backgroundVideoFormat = BackgroundVideoFormat.VideoFormat2K;

        [SerializeField] private bool _sessionShouldAttemptRelocalization = false;

        public Transform CenterEyePose
        {
            get
            {
                return _centerEyePose;
            }
        }

        public HoloKitRenderMode RenderMode
        {
            get => _renderMode;
            set
            {
                _renderMode = value;
                SetupRenderMode();
                OnRenderModeChanged?.Invoke(HoloKitRenderMode.Mono);
            }
        }

        public BackgroundVideoFormat BackgroundVideoFormat
        {
            get => _backgroundVideoFormat;
            set
            {
                _backgroundVideoFormat = value;
            }
        }

        public bool SessionShouldAttemptRelocalization
        {
            get => _sessionShouldAttemptRelocalization;
            set
            {
                _sessionShouldAttemptRelocalization = value;
                HoloKitARSessionManagerNativeInterface.SetSessionShouldAttemptRelocalization(_sessionShouldAttemptRelocalization);
            }
        }

        public float ARSessionStartTime => _arSessionStartTime;

        private HoloKitRenderMode _renderMode = HoloKitRenderMode.Mono;

        private Vector3 _cameraToCenterEyeOffset;

        private float _arSessionStartTime;

        private ARCameraBackground _arCameraBackground;

        /// <summary>
        /// The default ARFoundation tracked pose driver. We use this to control
        /// the camera pose in mono mode.
        /// </summary>
        private TrackedPoseDriver _defaultTrackedPoseDriver;

        /// <summary>
        /// We use this to control the camera pose in star mode.
        /// </summary>
        private HoloKitTrackedPoseDriver _holokitTrackedPoseDriver;

        /// <summary>
        /// Increase iOS screen brightness gradually in each frame.
        /// </summary>
        private const float SCREEN_BRIGHTNESS_INCREASE_STEP = 0.005f;

        /// <summary>
        /// Invoked when the render mode changes.
        /// </summary>
        public static event Action<HoloKitRenderMode> OnRenderModeChanged;

        public static event Action<CameraTrackingState> OnCameraChangedTrackingState;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
            }
            else
            {
                _instance = this;
            }
        }

        private void Start()
        {
            if (PlatformChecker.IsRuntime)
            {
                UnityEngine.iOS.Device.hideHomeButton = true;
                Screen.sleepTimeout = SleepTimeout.NeverSleep;

                SetupHoloKitCameraData(HoloKitStarManagerNativeInterface.GetHoloKitCameraData(_ipd, _farClipPlane));
            }

            // Get the reference of tracked pose drivers
            _defaultTrackedPoseDriver = GetComponent<TrackedPoseDriver>();
            _holokitTrackedPoseDriver = GetComponent<HoloKitTrackedPoseDriver>();

            HoloKitARSessionManagerNativeInterface.SetBackgroundVideoFormat(_backgroundVideoFormat);
            HoloKitARSessionManagerNativeInterface.SetSessionShouldAttemptRelocalization(_sessionShouldAttemptRelocalization);

            _arCameraBackground = GetComponent<ARCameraBackground>();
            SetupRenderMode();

            _arSessionStartTime = Time.time;

            HoloKitARSessionManagerNativeInterface.OnCameraChangedTrackingState += OnCameraChangedTrackingState;
        }

        private void OnDestroy()
        {
            HoloKitARSessionManagerNativeInterface.OnCameraChangedTrackingState -= OnCameraChangedTrackingState;
        }

        private void Update()
        {
            if (_renderMode == HoloKitRenderMode.Stereo)
            {
                if (PlatformChecker.IsRuntime)
                {
                    // Force screen brightness to be 1 in StAR mode
                    var screenBrightness = HoloKitIOSManagerNativeInterface.GetScreenBrightness();
                    if (screenBrightness < 1f)
                    {
                        var newScreenBrightness = screenBrightness + SCREEN_BRIGHTNESS_INCREASE_STEP;
                        if (newScreenBrightness > 1f)
                            newScreenBrightness = 1f;
                        HoloKitIOSManagerNativeInterface.SetScreenBrightness(newScreenBrightness);
                        HoloKitIOSManagerNativeInterface.SetScreenBrightness(1f);
                    }
                }

                if (Screen.orientation != ScreenOrientation.LandscapeLeft)
                    Screen.orientation = ScreenOrientation.LandscapeLeft;
            }
        }

        public void SetupHoloKitCameraData(HoloKitCameraData holokitCameraData)
        {
            _leftEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToLeftEyeOffset;
            _rightEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToRightEyeOffset;

            // Setup left eye camera
            _leftEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            _leftEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            _leftEyeCamera.rect = holokitCameraData.LeftViewportRect;
            _leftEyeCamera.projectionMatrix = holokitCameraData.LeftProjectionMatrix;
            // Setup right eye camera
            _rightEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            _rightEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            _rightEyeCamera.rect = holokitCameraData.RightViewportRect;
            _rightEyeCamera.projectionMatrix = holokitCameraData.RightProjectionMatrix;

            _cameraToCenterEyeOffset = holokitCameraData.CameraToCenterEyeOffset;
        }

        private void SetupRenderMode()
        {
            if (_renderMode == HoloKitRenderMode.Stereo)
            {
                // Switch ARBackground
                _arCameraBackground.enabled = false;
                // Switch cameras
                _monoCamera.enabled = false;
                _leftEyeCamera.gameObject.SetActive(true);
                _rightEyeCamera.gameObject.SetActive(true);
                _blackCamera.gameObject.SetActive(true);
                // Set center eye pose offset
                _centerEyePose.localPosition = _cameraToCenterEyeOffset;
                // Switch tracked pose driver
                _defaultTrackedPoseDriver.enabled = false;
                _holokitTrackedPoseDriver.IsActive = true;
            }
            else
            {
                // Switch ARBackground
                _arCameraBackground.enabled = true;
                // Switch cameras
                _monoCamera.enabled = true;
                _leftEyeCamera.gameObject.SetActive(false);
                _rightEyeCamera.gameObject.SetActive(false);
                _blackCamera.gameObject.SetActive(false);
                // Reset center eye pose offset
                _centerEyePose.localPosition = Vector3.zero;
                // Switch tracked pose driver
                _defaultTrackedPoseDriver.enabled = true;
                _holokitTrackedPoseDriver.IsActive = false;
            }
        }
    }
}
