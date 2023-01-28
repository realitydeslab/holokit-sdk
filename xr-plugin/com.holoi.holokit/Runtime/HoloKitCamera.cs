using System;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.InputSystem.XR;
using Holoi.HoloKit.NativeInterface;

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
                if (_renderMode != value)
                {
                    if (value == HoloKitRenderMode.Stereo)
                    {
                        //HoloKitNFCSessionControllerAPI.StartNFCSession(HoloKitType.HoloKitX, _ipd, _farClipPlane);
                    }
                    else
                    {
                        _renderMode = HoloKitRenderMode.Mono;
                        OnRenderModeChanged();
                        OnHoloKitRenderModeChanged?.Invoke(HoloKitRenderMode.Mono);
                    }
                }
            }
        }

        public float AlignmentMarkerOffset => _alignmentMarkerOffset;

        public float ARSessionStartTime => _arSessionStartTime;

        private HoloKitRenderMode _renderMode = HoloKitRenderMode.Mono;

        private float _alignmentMarkerOffset;

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
        private const float ScreenBrightnessIncreaseStep = 0.005f;

        public static event Action<HoloKitRenderMode> OnHoloKitRenderModeChanged;

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
            // iOS screen system settings
            //if (HoloKitUtils.IsRuntime)
            //{
            //    UnityEngine.iOS.Device.hideHomeButton = true;
            //    Screen.sleepTimeout = SleepTimeout.NeverSleep;
            //}

            //// Get the reference of tracked pose drivers
            //_defaultTrackedPoseDriver = GetComponent<TrackedPoseDriver>();
            //_holokitTrackedPoseDriver = GetComponent<HoloKitTrackedPoseDriver>();

            //HoloKitNFCSessionControllerAPI.OnNFCSessionCompleted += OnNFCSessionCompleted;
            ////HoloKitARSessionControllerAPI.ResetARSessionFirstFrame();
            ////HoloKitARSessionControllerAPI.SetVideoEnhancementMode(_videoEnhancementMode);

            //_arCameraBackground = GetComponent<ARCameraBackground>();
            //OnRenderModeChanged();
  
            //_arSessionStartTime = Time.time;
        }

        private void Update()
        {
            if (_renderMode == HoloKitRenderMode.Stereo)
            {
                //if (HoloKitUtils.IsRuntime)
                //{
                //    // Force screen brightness to be 1 in StAR mode
                //    //var screenBrightness = HoloKitARSessionControllerAPI.GetScreenBrightness();
                //    //if (screenBrightness < 1f)
                //    //{
                //    //    var newScreenBrightness = screenBrightness + ScreenBrightnessIncreaseStep;
                //    //    if (newScreenBrightness > 1f) newScreenBrightness = 1f;
                //    //    HoloKitARSessionControllerAPI.SetScreenBrightness(newScreenBrightness);
                //    //    HoloKitARSessionControllerAPI.SetScreenBrightness(1f);
                //    //}
                //}

                if (Screen.orientation != ScreenOrientation.LandscapeLeft)
                    Screen.orientation = ScreenOrientation.LandscapeLeft;
            }
        }

        private void OnDestroy()
        {
            //HoloKitNFCSessionControllerAPI.OnNFCSessionCompleted -= OnNFCSessionCompleted;
        }

        public void SetupHoloKitCameraData(HoloKitCameraData holokitCameraData)
        {
            _centerEyePose.localPosition = holokitCameraData.CameraToCenterEyeOffset;
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

            _alignmentMarkerOffset = holokitCameraData.AlignmentMarkerOffset;
        }

        private void OnRenderModeChanged()
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

        private void OnNFCSessionCompleted(bool success)
        {
            if (success)
            {
                _renderMode = HoloKitRenderMode.Stereo;
                OnRenderModeChanged();
                OnHoloKitRenderModeChanged?.Invoke(HoloKitRenderMode.Stereo);
            }
        }

        public void OpenStereoWithoutNFC(string password)
        {
            //HoloKitNFCSessionControllerAPI.SkipNFCSessionWithPassword(password, HoloKitType.HoloKitX, _ipd, _farClipPlane);
        }
    }
}
