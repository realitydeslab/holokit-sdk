using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.XR;

namespace HoloKit
{
    public struct NullablePose
    {
        public Vector3? position;
        public Quaternion? rotation;
    }

    [DisallowMultipleComponent]
    [RequireComponent(typeof(Camera))]
    public class HoloKitPoseDriver: MonoBehaviour
    {
        static internal InputDevice? s_InputTrackingDevice = null;

        protected void Awake()
        {
        }

        protected void OnEnable()
        {
            Application.onBeforeRender += OnBeforeRender;

            List<InputDevice> devices = new List<InputDevice>();
            InputDevices.GetDevicesWithCharacteristics(InputDeviceCharacteristics.HeadMounted | InputDeviceCharacteristics.TrackedDevice, devices);
            foreach (var device in devices)
            {
                Debug.Log($"{device.name}");
                CheckConnectedDevice(device, false);
            }
            InputDevices.deviceConnected += OnInputDeviceConnected;
        }

        protected void OnDisable()
        {            
            Application.onBeforeRender -= OnBeforeRender;
            InputDevices.deviceConnected -= OnInputDeviceConnected;
        }

        protected void Update()
        {
//            Debug.Log("Update at " + HoloKitHeadTracking.Instance.GetCurrentTime());

            PerformUpdate();
        }

        protected void OnBeforeRender()
        {
//            Debug.Log("OnBeforeRender at " + HoloKitHeadTracking.Instance.GetCurrentTime());

            PerformUpdate();
        }

        protected void PerformUpdate()
        {
            if (!enabled)
                return;

            var updatedPose = GetPose();

            if (updatedPose.position.HasValue)
                transform.localPosition = updatedPose.position.Value;
            if (updatedPose.rotation.HasValue)
                transform.localRotation = updatedPose.rotation.Value;
        }

        static internal NullablePose GetPose()
        {
            return GetPoseData();
        }

        void OnInputDeviceConnected(InputDevice device)
        {
            CheckConnectedDevice(device);
        }

        void CheckConnectedDevice(InputDevice device, bool displayWarning = true)
        {
            Debug.Log("fuck");

            if (!device.characteristics.HasFlag(InputDeviceCharacteristics.HeadMounted | InputDeviceCharacteristics.TrackedDevice)) {
                return;
            }

            if (device.name != "HoloKit HMD") {
                return;
            }

            var positionSuccess = device.TryGetFeatureValue(CommonUsages.centerEyePosition, out Vector3 position);
            var rotationSuccess = device.TryGetFeatureValue(CommonUsages.centerEyeRotation, out Quaternion rotation);

            if (positionSuccess && rotationSuccess)
            {
                if (s_InputTrackingDevice == null)
                {
                    s_InputTrackingDevice = device;
                    Debug.Log($"{device.name} added");
                }
                else
                {
                    Debug.LogWarning($"An input device {device.name} with the TrackedDevice characteristic was registered but the ARPoseDriver is already consuming data from {s_InputTrackingDevice.Value.name}.");
                }
            }
        }

        static internal NullablePose GetPoseData()
        {
            NullablePose resultPose = new NullablePose();

            if (s_InputTrackingDevice != null)
            {
                var pose = Pose.identity;
                var positionSuccess = s_InputTrackingDevice.Value.TryGetFeatureValue(CommonUsages.centerEyePosition, out pose.position);
                var rotationSuccess = s_InputTrackingDevice.Value.TryGetFeatureValue(CommonUsages.centerEyeRotation, out pose.rotation);

                if (positionSuccess)
                    resultPose.position = pose.position;
                if (rotationSuccess)
                    resultPose.rotation = pose.rotation;

                if (positionSuccess || rotationSuccess)
                    return resultPose;
            }

            return resultPose;
        }
    }
}
