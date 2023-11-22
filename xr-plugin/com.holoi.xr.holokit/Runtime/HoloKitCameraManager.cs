// SPDX-FileCopyrightText: Copyright 2023 Holo Interactive <dev@holoi.com>
// SPDX-FileContributor: Yuchen Zhang <yuchen@holoi.com>
// SPDX-License-Identifier: MIT

using System;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.InputSystem.XR;

namespace HoloKit
{
    public struct HoloKitCameraData
    {
        public Rect LeftViewportRect;
        public Rect RightViewportRect;
        public float NearClipPlane;
        public float FarClipPlane;
        public Matrix4x4 LeftProjectionMatrix;
        public Matrix4x4 RightProjectionMatrix;
        public Vector3 CameraToCenterEyeOffset;
        public Vector3 CameraToScreenCenterOffset;
        public Vector3 CenterEyeToLeftEyeOffset;
        public Vector3 CenterEyeToRightEyeOffset;
        // The horizontal distance from the screen center in pixels
        public float AlignmentMarkerOffset;
    }

    public enum HoloKitRenderMode
    {
        Mono = 0,
        Stereo = 1
    }

    public enum VideoEnhancementMode
    {
        None = 0,      // Default HD
        HighRes = 1,   // 4K
        HighResWithHDR // 4K with HDR
    }

    public class HoloKitCameraManager : MonoBehaviour
    {
        public static HoloKitCameraManager Instance { get { return m_instance; } }

        private static HoloKitCameraManager m_instance;

        [SerializeField] internal Transform m_centerEyePose;

        [SerializeField] internal Camera m_monoCamera;

        [SerializeField] internal Camera m_leftEyeCamera;

        [SerializeField] internal Camera m_rightEyeCamera;

        [SerializeField] internal Camera m_blackCamera;

        [SerializeField]
        [Range(0.054f, 0.074f)]
        internal float m_ipd = 0.064f;

        [SerializeField] internal float m_farClipPlane = 50f;

        /// <summary>
        /// This value can only be set before the first ARSession frame.
        /// </summary>
        [SerializeField] private VideoEnhancementMode m_videoEnhancementMode = VideoEnhancementMode.None;

        /// <summary>
        /// If this value is set to true, the screen orientation will be set automatically
        /// based on the current render mode. The screen orientation will be set to
        /// Portrait if the current render mode is Mono. The screen orientation will be
        /// set to LandscapeLeft if the current render mode is Stereo.
        /// </summary>
        [SerializeField] private bool m_forceScreenOrientation = true;

        public Transform CenterEyePose
        {
            get
            {
                return m_centerEyePose;
            }
        }

        public HoloKitRenderMode RenderMode
        {
            get => m_renderMode;
            set
            {
                if (m_renderMode != value)
                {
                    if (value == HoloKitRenderMode.Stereo)
                    {
                        HoloKitNFCSessionControllerAPI.StartNFCSession(HoloKitType.HoloKitX, m_ipd, m_farClipPlane);
                    }
                    else
                    {
                        m_renderMode = HoloKitRenderMode.Mono;
                        OnRenderModeChanged();
                        OnHoloKitRenderModeChanged?.Invoke(HoloKitRenderMode.Mono);
                    }
                }
            }
        }

        public VideoEnhancementMode VideoEnhancementMode
        {
            get => m_videoEnhancementMode;
            set
            {
                m_videoEnhancementMode = value;
            }
        }

        public float AlignmentMarkerOffset => m_alignmentMarkerOffset;

        public float ARSessionStartTime => m_arSessionStartTime;

        public bool ForceScreenOrientation
        {
            get => m_forceScreenOrientation;
            set
            {
                m_forceScreenOrientation = value;
            }
        }

        private HoloKitRenderMode m_renderMode = HoloKitRenderMode.Mono;

        private float m_alignmentMarkerOffset;

        private float m_arSessionStartTime;

        private ARCameraBackground m_arCameraBackground;

        /// <summary>
        /// The default ARFoundation tracked pose driver. We use this to control
        /// the camera pose in mono mode.
        /// </summary>
        private TrackedPoseDriver m_defaultTrackedPoseDriver;

        /// <summary>
        /// We use this to control the camera pose in star mode.
        /// </summary>
        private HoloKitTrackedPoseDriver m_holokitTrackedPoseDriver;

        /// <summary>
        /// Increase iOS screen brightness gradually in each frame.
        /// </summary>
        private const float ScreenBrightnessIncreaseStep = 0.005f;

        public static event Action<HoloKitRenderMode> OnHoloKitRenderModeChanged;

        private void Awake()
        {
            if (m_instance != null && m_instance != this)
            {
                Destroy(gameObject);
            }
            else
            {
                m_instance = this;
            }
        }

        private void Start()
        {
            // iOS screen system settings
            if (HoloKitUtils.IsRuntime)
            {
                UnityEngine.iOS.Device.hideHomeButton = true;
                Screen.sleepTimeout = SleepTimeout.NeverSleep;
            }

            // Get the reference of tracked pose drivers
            m_defaultTrackedPoseDriver = GetComponent<TrackedPoseDriver>();
            m_holokitTrackedPoseDriver = GetComponent<HoloKitTrackedPoseDriver>();

            HoloKitNFCSessionControllerAPI.OnNFCSessionCompleted += OnNFCSessionCompleted;
            HoloKitARSessionControllerAPI.ResetARSessionFirstFrame();
            HoloKitARSessionControllerAPI.SetVideoEnhancementMode(m_videoEnhancementMode);

            m_arCameraBackground = GetComponent<ARCameraBackground>();
            OnRenderModeChanged();
  
            m_arSessionStartTime = Time.time;
        }

        private void Update()
        {
            if (m_renderMode == HoloKitRenderMode.Stereo)
            {
                if (HoloKitUtils.IsRuntime)
                {
                    // Force screen brightness to be 1 in StAR mode
                    var screenBrightness = HoloKitARSessionControllerAPI.GetScreenBrightness();
                    if (screenBrightness < 1f)
                    {
                        var newScreenBrightness = screenBrightness + ScreenBrightnessIncreaseStep;
                        if (newScreenBrightness > 1f) newScreenBrightness = 1f;
                        HoloKitARSessionControllerAPI.SetScreenBrightness(newScreenBrightness);
                        HoloKitARSessionControllerAPI.SetScreenBrightness(1f);
                    }
                }

                if (Screen.orientation != ScreenOrientation.LandscapeLeft)
                    Screen.orientation = ScreenOrientation.LandscapeLeft;
            }
            else
            {
                if (m_forceScreenOrientation)
                {
                    if (Screen.orientation != ScreenOrientation.Portrait)
                        Screen.orientation = ScreenOrientation.Portrait;
                }
            }
        }

        private void OnDestroy()
        {
            HoloKitNFCSessionControllerAPI.OnNFCSessionCompleted -= OnNFCSessionCompleted;
        }

        public void SetupHoloKitCameraData(HoloKitCameraData holokitCameraData)
        {
            m_centerEyePose.localPosition = holokitCameraData.CameraToCenterEyeOffset;
            m_leftEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToLeftEyeOffset;
            m_rightEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToRightEyeOffset;

            // Setup left eye camera
            m_leftEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            m_leftEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            m_leftEyeCamera.rect = holokitCameraData.LeftViewportRect;
            m_leftEyeCamera.projectionMatrix = holokitCameraData.LeftProjectionMatrix;
            // Setup right eye camera
            m_rightEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            m_rightEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            m_rightEyeCamera.rect = holokitCameraData.RightViewportRect;
            m_rightEyeCamera.projectionMatrix = holokitCameraData.RightProjectionMatrix;

            m_alignmentMarkerOffset = holokitCameraData.AlignmentMarkerOffset;
        }

        private void OnRenderModeChanged()
        {
            if (m_renderMode == HoloKitRenderMode.Stereo)
            {
                // Switch ARBackground
                m_arCameraBackground.enabled = false;
                // Switch cameras
                m_monoCamera.enabled = false;
                m_leftEyeCamera.gameObject.SetActive(true);
                m_rightEyeCamera.gameObject.SetActive(true);
                m_blackCamera.gameObject.SetActive(true);
                // Switch tracked pose driver
                m_defaultTrackedPoseDriver.enabled = false;
            }
            else
            {
                // Switch ARBackground
                m_arCameraBackground.enabled = true;
                // Switch cameras
                m_monoCamera.enabled = true;
                m_leftEyeCamera.gameObject.SetActive(false);
                m_rightEyeCamera.gameObject.SetActive(false);
                m_blackCamera.gameObject.SetActive(false);
                // Reset center eye pose offset
                m_centerEyePose.localPosition = Vector3.zero;
                // Switch tracked pose driver
                m_defaultTrackedPoseDriver.enabled = true;
            }
        }

        private void OnNFCSessionCompleted(bool success)
        {
            if (success)
            {
                m_renderMode = HoloKitRenderMode.Stereo;
                OnRenderModeChanged();
                OnHoloKitRenderModeChanged?.Invoke(HoloKitRenderMode.Stereo);
            }
        }

        public void OpenStereoWithoutNFC(string password)
        {
            HoloKitNFCSessionControllerAPI.SkipNFCSessionWithPassword(password, HoloKitType.HoloKitX, m_ipd, m_farClipPlane);
        }
    }
}
