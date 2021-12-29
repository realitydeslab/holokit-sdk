using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.Events;
using System;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitManager : MonoBehaviour
    {
        private static HoloKitManager _instance;

        public static HoloKitManager Instance { get { return _instance; } }

        private XRDisplaySubsystem m_DisplaySubsystem;

        public XRDisplaySubsystem DisplaySubsystem
        {
            get => m_DisplaySubsystem;
        }

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

        public Transform CenterEyePoint;

        //public bool LowLatencyTrackingActive
        //{
        //    get => UnityHoloKit_GetLowLatencyTrackingApiActive();
        //}

        //private ARKitCameraTrackingState m_CurrentCameraTrackingState;

        //private ARKitCameraTrackingState m_NewCameraTrackingState;

        public event UnityAction DidChange2StAREvent;

        public event UnityAction DidChange2AREvent;

        public event UnityAction<iOSThermalState> ThermalStateDidChangeEvent;

        public event UnityAction<ARKitCameraTrackingState> CameraDidChangeTrackingStateEvent; 

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

        //[DllImport("__Internal")]
        //private static extern bool UnityHoloKit_GetLowLatencyTrackingApiActive();

        //[DllImport("__Internal")]
        //private static extern void UnityHoloKit_SetLowLatencyTrackingApiActive(bool value);

        [DllImport("__Internal")]
        private static extern int UnityHoloKit_GetThermalState();

        delegate void ThermalStateDidChange(int state);
        [AOT.MonoPInvokeCallback(typeof(ThermalStateDidChange))]
        private static void OnThermalStateDidChange(int state)
        {
            Instance.ThermalStateDidChangeEvent?.Invoke((iOSThermalState)state);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetThermalStateDidChangeDelegate(ThermalStateDidChange callback);

        delegate void CameraDidChangeTrackingState(int trackingState);
        [AOT.MonoPInvokeCallback(typeof(CameraDidChangeTrackingState))]
        private static void OnCameraDidChangeTrackingState(int trackingState)
        {
            //Instance.m_NewCameraTrackingState = (ARKitCameraTrackingState)trackingState;
            Instance.CameraDidChangeTrackingStateEvent?.Invoke((ARKitCameraTrackingState)trackingState);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(CameraDidChangeTrackingState callback);

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
            // Get camera to center eye offset from sdk.
            IntPtr offsetPtr = UnityHoloKit_GetCameraToCenterEyeOffsetPtr();
            float[] offset = new float[3];
            Marshal.Copy(offsetPtr, offset, 0, 3);
            m_CameraToCenterEyeOffset = new Vector3(offset[0], offset[1], -offset[2]);
            UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(offsetPtr);

            // Get a reference of the display subsystem.
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            if (displaySubsystems.Count > 0)
            {
                m_DisplaySubsystem = displaySubsystems[0];
            }

            m_ARCameraBackground = Camera.main.GetComponent<ARCameraBackground>();

            //m_CurrentCameraTrackingState = ARKitCameraTrackingState.NotAvailable;

            UnityHoloKit_SetSetARCameraBackgroundDelegate(OnSetARCameraBackground);
            UnityHoloKit_SetThermalStateDidChangeDelegate(OnThermalStateDidChange);
            UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(OnCameraDidChangeTrackingState);
        }

        private void OnDisable()
        {

        }

        private void Start()
        {
            Screen.brightness = 1.0f;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            iOS.Device.hideHomeButton = true;
        }

        //private void Update()
        //{
        //    if (m_CurrentCameraTrackingState != m_NewCameraTrackingState)
        //    {
        //        CameraDidChangeTrackingStateEvent?.Invoke(m_NewCameraTrackingState);
        //        m_CurrentCameraTrackingState = m_NewCameraTrackingState;
        //    }
        //}

        public bool EnableStereoscopicRendering(bool value)
        {
            if (value)
            {
                if (UnityHoloKit_StartNfcSession())
                {
                    UnityHoloKit_EnableStereoscopicRendering(true);
                    m_DisplaySubsystem.Start();
                    CenterEyePoint.localPosition = m_CameraToCenterEyeOffset;
                    DidChange2StAREvent?.Invoke();
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
                CenterEyePoint.localPosition = Vector3.zero;
                DidChange2AREvent?.Invoke();
                return true;
            }
        }

        //public void SetLowLatencyTrackingActive(bool value)
        //{
        //    UnityHoloKit_SetLowLatencyTrackingApiActive(value);
        //}

        public iOSThermalState GetThermalState()
        {
            return (iOSThermalState)UnityHoloKit_GetThermalState();
        }
    }
}