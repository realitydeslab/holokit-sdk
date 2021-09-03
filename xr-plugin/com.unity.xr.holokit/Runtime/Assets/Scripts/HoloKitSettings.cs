using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using System;

namespace UnityEngine.XR.HoloKit
{
    /// <summary>
    /// This is a master class to help Unity communiate with HoloKit SDK. 
    /// </summary>
    public class HoloKitSettings : MonoBehaviour
    {
        // This class is a singleton.
        private static HoloKitSettings _instance;

        public static HoloKitSettings Instance { get { return _instance; } }

        [SerializeField] private bool m_CollaborationEnabled = false;

        private XRDisplaySubsystem m_DisplaySubsystem;

        public XRDisplaySubsystem DisplaySubsystem
        {
            get => m_DisplaySubsystem;
        }

        private RenderTexture m_SecondCameraRenderTexture;

        public RenderTexture SecondCameraRenderTexture
        {
            get => m_SecondCameraRenderTexture;
        }

        private Display m_SecondDisplay = null;

        private static Vector3 m_CameraToCenterEyeOffset;

        public static Vector3 CameraToCenterEyeOffset
        {
            get => m_CameraToCenterEyeOffset;
        }

        private ARCameraBackground m_ARCameraBackground;

        public bool StereoscopicRendering
        {
            get => UnityHoloKit_StereoscopicRendering();
        }

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_StereoscopicRendering();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetStereoscopicRendering(bool value);

        delegate void SetARCameraBackground(bool value);
        [AOT.MonoPInvokeCallback(typeof(SetARCameraBackground))]
        private static void OnSetARCameraBackground(bool value)
        {
            Instance.m_ARCameraBackground.enabled = value;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSetARCameraBackgroundDelegate(SetARCameraBackground callback);

        [DllImport("__Internal")]
        private static extern IntPtr UnityHoloKit_GetCameraToCenterEyeOffsetPtr();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(IntPtr ptr);

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_StartNfcSession();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSecondDisplayAvailable(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSecondDisplayNativeRenderBufferPtr(IntPtr nativeRenderBufferPtr);

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

        private void OnEnable()
        {
            // Set up the collaboration setting.
            if (m_CollaborationEnabled)
            {
                ARSession session = FindObjectOfType<ARSession>();
                ARKitSessionSubsystem subsystem = session.subsystem as ARKitSessionSubsystem;
                subsystem.collaborationRequested = true;
            }

            // Set the screen brightness to the maximum.
            Screen.brightness = 1.0f;

            // Retrive camera to center eye offset from objective-c side.
            // https://stackoverflow.com/questions/17634480/return-c-array-to-c-sharp/18041888
            IntPtr offsetPtr = UnityHoloKit_GetCameraToCenterEyeOffsetPtr();
            float[] offset = new float[3];
            Marshal.Copy(offsetPtr, offset, 0, 3);
            Debug.Log($"[HoloKitSettings]: camera to center eye offset [{offset[0]}, {offset[1]}, {-offset[2]}]");
            m_CameraToCenterEyeOffset = new Vector3(offset[0], offset[1], -offset[2]);
            UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(offsetPtr);

            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            Debug.Log($"Number of display subsystem {displaySubsystems.Count}");
            if (displaySubsystems.Count > 0)
            {
                m_DisplaySubsystem = displaySubsystems[0];
            }

            m_ARCameraBackground = Camera.main.GetComponent<ARCameraBackground>();

            UnityHoloKit_SetSetARCameraBackgroundDelegate(OnSetARCameraBackground);
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

        public bool SetStereoscopicRendering(bool value)
        {
            if (value)
            {
                if (UnityHoloKit_StartNfcSession())
                {
                    UnityHoloKit_SetStereoscopicRendering(true);
                    m_DisplaySubsystem.Start();
                    return true;
                }
                else
                {
                    return false;
                }
            }
            else
            {
                m_DisplaySubsystem.Stop();
                UnityHoloKit_SetStereoscopicRendering(false);
                return true;
            }
        }
    }
}