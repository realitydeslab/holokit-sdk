using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using System;
using UnityEngine.Rendering;

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

        public bool IsStereoscopicRendering
        {
            get => UnityHoloKit_IsStereoscopicRendering();
        }

        private int m_CurrentRenderPass = 0;

        public int CurrentRenderPass
        {
            get => m_CurrentRenderPass;
            set
            {
                m_CurrentRenderPass = value;
            }
        }

        [SerializeField] private Transform m_CenterEyePoint;

        [SerializeField] private GameObject m_SecondARReplayCamera;

        public Camera ReplayCamera
        {
            get
            {
                if (IsStereoscopicRendering)
                {
                    return m_SecondARReplayCamera.GetComponent<Camera>();
                }
                else
                {
                    return Camera.main;
                }
            }
        }

        public bool LowLatencyTrackingActive
        {
            get => UnityHoloKit_GetLowLatencyTrackingApiActive();
        }

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_IsStereoscopicRendering();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_EnableStereoscopicRendering(bool value);

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
        private static extern bool UnityHoloKit_GetLowLatencyTrackingApiActive();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetLowLatencyTrackingApiActive(bool value);

        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetThermalState();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_EnableShareARCollaborationData(bool val);

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

            RenderPipelineManager.beginFrameRendering += OnBeginFrameRendering;
            RenderPipelineManager.endFrameRendering += OnEndFrameRendering;
        }

        private void OnDisable()
        {
            RenderPipelineManager.beginFrameRendering -= OnBeginFrameRendering;
            RenderPipelineManager.endFrameRendering -= OnEndFrameRendering;
        }

        private void Start()
        {
            // Let it be bright.
            Screen.brightness = 1.0f;

            // Do not sleep.
            Screen.sleepTimeout = SleepTimeout.NeverSleep;

            iOS.Device.hideHomeButton = true;
        }

        private void Update()
        {
            
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
                    UnityHoloKit_EnableStereoscopicRendering(true);
                    m_DisplaySubsystem.Start();

                    m_CenterEyePoint.localPosition = m_CameraToCenterEyeOffset;
                    //m_SecondARReplayCamera.SetActive(true);
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
                UnityHoloKit_EnableStereoscopicRendering(false);

                m_CenterEyePoint.localPosition = Vector3.zero;
                //m_SecondARReplayCamera.SetActive(false);
                return true;
            }
        }

        public void SetLowLatencyTrackingActive(bool value)
        {
            UnityHoloKit_SetLowLatencyTrackingApiActive(value);
        }

        private void OnBeginFrameRendering(ScriptableRenderContext context, Camera[] cameras)
        {

        }

        private void OnEndFrameRendering(ScriptableRenderContext context, Camera[] cameras)
        {
            //UnityHoloKit_UpdateLastRenderTime();
        }

        public iOSThermalState GetThermalState()
        {
            return (iOSThermalState)UnityHoloKit_GetThermalState();
        }

        public void EnableShareARCollaborationData(bool val)
        {
            UnityHoloKit_EnableShareARCollaborationData(val);
        }
    }
}