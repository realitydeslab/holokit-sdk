using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using System;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitSettings : MonoBehaviour
    {
        // This class is a singleton.
        private static HoloKitSettings _instance;

        public static HoloKitSettings Instance { get { return _instance; } }

        [SerializeField] private bool m_XrModeEnabled = true;

        [SerializeField] private bool m_CollaborationEnabled = false;

        private Camera arCamera;

        public static Vector3 CameraToCenterEyeOffset;

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetRenderingMode(int val);

        [DllImport("__Internal")]
        public static extern IntPtr UnityHoloKit_GetCameraToCenterEyeOffsetPtr();

        [DllImport("__Internal")]
        public static extern int UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(IntPtr ptr);

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(this.gameObject);
            }
            else
            {
                _instance = this;
            }
        }

        void OnEnable()
        {
            arCamera = Camera.main;

            // Set the rendering mode.
            if (m_XrModeEnabled)
            {
                UnityHoloKit_SetRenderingMode(2);
                arCamera.GetComponent<ARCameraBackground>().enabled = false;
            }
            else
            {
                UnityHoloKit_SetRenderingMode(1);
                arCamera.GetComponent<ARCameraBackground>().enabled = true;
            }

            // Set up the collaboration setting.
            if (m_CollaborationEnabled)
            {
                ARSession session = FindObjectOfType<ARSession>();
                ARKitSessionSubsystem subsystem = session.subsystem as ARKitSessionSubsystem;
                subsystem.collaborationRequested = true;
            }

            // Set the screen brightness to the maximum.
            Screen.brightness = 1.0f;

            // Calculate camera to center eye offset.
            // https://stackoverflow.com/questions/17634480/return-c-array-to-c-sharp/18041888
            IntPtr offsetPtr = UnityHoloKit_GetCameraToCenterEyeOffsetPtr();
            float[] offset = new float[3];
            Marshal.Copy(offsetPtr, offset, 0, 3);
            Debug.Log($"[HoloKitSettings]: camera to center eye offset [{offset[0]}, {offset[1]}, {offset[2]}]");
            CameraToCenterEyeOffset = new Vector3(offset[0], offset[1], offset[2]);
            UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(offsetPtr);
        }

        public void EnableMeshing(bool enabled)
        {
            // We can only enable one of them at the same time.
            if (enabled)
            {
                EnableMeshing(false);
            }
            transform.GetChild(0).GetChild(1).gameObject.SetActive(enabled);
        }

        public void EnablePlaneDetection(bool enabled)
        {
            // We can only enable one of them at the same time.
            if (enabled)
            {
                EnablePlaneDetection(false);
            }
            transform.GetChild(0).GetComponent<ARPlaneManager>().enabled = enabled;
        }
    }
}