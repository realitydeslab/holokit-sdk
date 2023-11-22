// SPDX-FileCopyrightText: Copyright 2023 Holo Interactive <dev@holoi.com>
// SPDX-FileContributor: Botao Amber Hu <botao@holoi.com>
// SPDX-FileContributor: Yuchen Zhang <yuchen@holoi.com>
// SPDX-License-Identifier: MIT

using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.ARFoundation;
using UnityEngine.InputSystem.XR;

namespace HoloKit
{
    [RequireComponent(typeof(ARCameraManager))]
    [RequireComponent(typeof(TrackedPoseDriver))]
    [RequireComponent(typeof(HoloKitCameraManager))]
    public class HoloKitTrackedPoseDriver : MonoBehaviour
    {
        private TrackedPoseDriver m_TrackedPoseDriver;

        private InputDevice m_InputDevice;

        private ARCameraManager m_ARCameraManager;

        private HoloKitCameraManager m_HoloKitCameraManager; 

        private IntPtr m_HeadTrackerPtr;

        private void Start()
        {
            m_ARCameraManager = GetComponent<ARCameraManager>();
            if (m_ARCameraManager == null)
            {
                Debug.LogWarning("[HoloKitTrackedPoseDriver] Failed to find ARCameraManager");
                return;
            }

            m_TrackedPoseDriver = GetComponent<TrackedPoseDriver>();
            if (m_TrackedPoseDriver == null)
            {
                Debug.LogWarning("[HoloKitTrackedPoseDriver] Failed to find TrackedPoseDriver");
                return;
            }

            List<InputDevice> devices = new();
            InputDevices.GetDevicesWithCharacteristics(InputDeviceCharacteristics.TrackedDevice | InputDeviceCharacteristics.HeadMounted, devices);
            if (devices.Count > 0)
                m_InputDevice = devices[0];
            if (m_InputDevice == null)
            {
                Debug.LogWarning("[HoloKitTrackedPoseDriver] Failed to find InputDevice");
                return;
            }

            m_HoloKitCameraManager = GetComponent<HoloKitCameraManager>();
            if (m_HoloKitCameraManager == null)
            {
                Debug.LogWarning("[HoloKitTrackedPoseDriver] Failed to find HoloKitCamera");
                return;
            }

#if UNITY_IOS && !UNITY_EDITOR
            HoloKitCamera.OnHoloKitRenderModeChanged += OnHoloKitRenderModeChanged;

            m_ARCameraManager.frameReceived += OnFrameReceived;

            Application.onBeforeRender += OnBeforeRender;

            m_HeadTrackerPtr = Init();
            InitHeadTracker(m_HeadTrackerPtr);
            PauseHeadTracker(m_HeadTrackerPtr);
#endif
        }

        private void Awake()
        {
            // HoloKitARSessionControllerAPI.OnARSessionUpdatedFrame += OnARSessionUpdatedFrame;
        }

#if UNITY_IOS && !UNITY_EDITOR

        private void OnBeforeRender()
        {
            if (m_HoloKitCameraManager.RenderMode == HoloKitRenderMode.Mono) {
                return;
            }

            UpdateHeadTrackerPose();
        }

        private void OnDestroy()
        {
            // HoloKitARSessionControllerAPI.OnARSessionUpdatedFrame -= OnARSessionUpdatedFrame;

            HoloKitCamera.OnHoloKitRenderModeChanged -= OnHoloKitRenderModeChanged;
            m_ARCameraManager.frameReceived -= OnFrameReceived;
            Application.onBeforeRender -= OnBeforeRender;
            Delete(m_HeadTrackerPtr);
        }

        private void OnHoloKitRenderModeChanged(HoloKitRenderMode renderMode)
        {
            if (renderMode == HoloKitRenderMode.Stereo)
            {
                ResumeHeadTracker(m_HeadTrackerPtr);
            }
            else
            {
                PauseHeadTracker(m_HeadTrackerPtr);
            }
        }

        private void OnFrameReceived(ARCameraFrameEventArgs args)
        {
            if (m_HoloKitCameraManager.RenderMode == HoloKitRenderMode.Mono) {
                return;
            }

            bool isPositionValid = m_InputDevice.TryGetFeatureValue(CommonUsages.centerEyePosition, out Vector3 position) || m_InputDevice.TryGetFeatureValue(CommonUsages.colorCameraPosition, out position);
            bool isRotationValid = m_InputDevice.TryGetFeatureValue(CommonUsages.centerEyeRotation, out Quaternion rotation) || m_InputDevice.TryGetFeatureValue(CommonUsages.colorCameraRotation, out rotation);

            if (isPositionValid && isRotationValid)
            {
                float[] positionArr = new float[] { position.x, position.y, position.z };
                float[] rotationArr = new float[] { rotation.x, rotation.y, rotation.z, rotation.w };
                AddSixDoFData(m_HeadTrackerPtr, (long) args.timestampNs, positionArr, rotationArr);
            }
        }

        private void UpdateHeadTrackerPose()
        {
            if (m_HoloKitCameraManager.RenderMode == HoloKitRenderMode.Mono) {
                return;
            }
            
            float[] positionArr = new float[3];
            float[] rotationArr = new float[4];

            GetHeadTrackerPose(m_HeadTrackerPtr, positionArr, rotationArr);
            Vector3 position = new(positionArr[0], positionArr[1], positionArr[2]);
            Quaternion rotation = new(rotationArr[0], rotationArr[1], rotationArr[2], rotationArr[3]);

            m_HoloKitCameraManager._centerEyePose.position = position;
            m_HoloKitCameraManager._centerEyePose.rotation = rotation;
        }

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_init")]
        static extern IntPtr Init();

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_initHeadTracker")]
        static extern void InitHeadTracker(IntPtr self);

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_pauseHeadTracker")]
        static extern void PauseHeadTracker(IntPtr self);

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_resumeHeadTracker")]
        static extern void ResumeHeadTracker(IntPtr self);

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_addSixDoFData")]
        static extern void AddSixDoFData(IntPtr self, long timestamp, [In] float[] position, [In] float[] orientation);

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_getHeadTrackerPose")]
        static extern void GetHeadTrackerPose(IntPtr self, [Out] float[] position, [Out] float[] orientation);

        [DllImport("__Internal", EntryPoint = "HoloKit_LowLatencyTracking_delete")]
        static extern void Delete(IntPtr self);
#endif
    }
}
