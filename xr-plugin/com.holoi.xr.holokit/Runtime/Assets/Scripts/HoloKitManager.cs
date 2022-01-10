using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.Events;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitManager : MonoBehaviour
    {
        private static HoloKitManager _instance;

        public static HoloKitManager Instance { get { return _instance; } }

        private XRDisplaySubsystem m_HoloKitDisplaySubsystem;

        //public XRDisplaySubsystem DisplaySubsystem
        //{
        //    get => m_DisplaySubsystem;
        //}

        private XRInputSubsystem m_HoloKitInputSubsystem;

        private static Vector3 k_CameraToCenterEyeOffset = new Vector3(0.0495f, -0.090635f, -0.07965f);

        public static Vector3 CameraToCenterEyeOffset
        {
            get => k_CameraToCenterEyeOffset;
        }

        private ARCameraBackground m_ARCameraBackground;

        public bool IsStereoscopicRendering
        {
            get => UnityHoloKit_GetIsStereoscopicRendering();
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
        private static extern bool UnityHoloKit_GetIsStereoscopicRendering();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetIsStereoscopicRendering(bool value);

        delegate void SetARCameraBackground(bool value);
        [AOT.MonoPInvokeCallback(typeof(SetARCameraBackground))]
        private static void OnSetARCameraBackground(bool value)
        {
            Instance.m_ARCameraBackground.enabled = value;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSetARCameraBackgroundDelegate(SetARCameraBackground callback);

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

            // Get the reference of the display subsystem.
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            if (displaySubsystems.Count > 0)
            {
                m_HoloKitDisplaySubsystem = displaySubsystems[0];
            }

            // Get the reference of the input subsystem.
            List<XRInputSubsystem> inputSubsystems = new List<XRInputSubsystem>();
            SubsystemManager.GetSubsystems(inputSubsystems);
            foreach (var inputSubsystem in inputSubsystems)
            {
                if (inputSubsystem.subsystemDescriptor.id.Equals("HoloKit Input"))
                {
                    m_HoloKitInputSubsystem = inputSubsystem;
                }
            }
            //m_HoloKitInputSubsystem.Stop();

            m_ARCameraBackground = Camera.main.GetComponent<ARCameraBackground>();

            UnityHoloKit_SetSetARCameraBackgroundDelegate(OnSetARCameraBackground);
            UnityHoloKit_SetThermalStateDidChangeDelegate(OnThermalStateDidChange);
            UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(OnCameraDidChangeTrackingState);
        }

        private void Start()
        {
            Screen.brightness = 1.0f;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            iOS.Device.hideHomeButton = true;

            if (FindObjectOfType<HandTrackingManager>() == null)
            {
                m_HoloKitInputSubsystem.Stop();
            }
        }

        private void OnDestroy()
        {
            
        }

        public bool EnableStereoscopicRendering(bool value)
        {
            if (value)
            {
                UnityHoloKit_SetIsStereoscopicRendering(true);
                m_HoloKitDisplaySubsystem.Start();
                CenterEyePoint.localPosition = k_CameraToCenterEyeOffset;
                DidChange2StAREvent?.Invoke();
                return true;
            }
            else
            {
                m_HoloKitDisplaySubsystem.Stop();
                UnityHoloKit_SetIsStereoscopicRendering(false);
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

        public void StartHoloKitInputSubsystem()
        {
            m_HoloKitInputSubsystem.Start();
        }

        public void StopHoloKitInputSubsystem()
        {
            m_HoloKitInputSubsystem.Stop();
        }
    }
}