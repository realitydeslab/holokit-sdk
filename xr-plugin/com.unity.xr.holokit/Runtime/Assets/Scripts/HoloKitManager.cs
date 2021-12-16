using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.Events;
using System;

namespace UnityEngine.XR.HoloKit
{
    /// <summary>
    /// This is a master class to help Unity communiate with HoloKit SDK. 
    /// </summary>
    public class HoloKitManager : MonoBehaviour
    {
        // This class is a singleton.
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

        [SerializeField] private Transform m_CenterEyePoint;

        public bool LowLatencyTrackingActive
        {
            get => UnityHoloKit_GetLowLatencyTrackingApiActive();
        }

        public event UnityAction<int> ThermalStateDidChangeEvent;

        public static event UnityAction DidChange2StAREvent;

        public static event UnityAction DidChange2AREvent;

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

        delegate void ThermalStateDidChange(int state);
        [AOT.MonoPInvokeCallback(typeof(ThermalStateDidChange))]
        private static void OnThermalStateDidChange(int state)
        {
            Debug.Log($"[HoloKitManager] thermal state changed to {(iOSThermalState)state}");
            Instance.ThermalStateDidChangeEvent?.Invoke(state);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetThermalStateDidChangeDelegate(ThermalStateDidChange callback);

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
            // Retrieve center eye offset from the SDK.
            // From https://stackoverflow.com/questions/17634480/return-c-array-to-c-sharp/18041888
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

            UnityHoloKit_SetSetARCameraBackgroundDelegate(OnSetARCameraBackground);
            UnityHoloKit_SetThermalStateDidChangeDelegate(OnThermalStateDidChange);
        }

        private void OnDisable()
        {

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

        public bool EnableStereoscopicRendering(bool value)
        {
            if (value)
            {
                if (UnityHoloKit_StartNfcSession())
                {
                    UnityHoloKit_EnableStereoscopicRendering(true);
                    m_DisplaySubsystem.Start();
                    m_CenterEyePoint.localPosition = m_CameraToCenterEyeOffset;
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
                m_CenterEyePoint.localPosition = Vector3.zero;
                DidChange2AREvent?.Invoke();
                return true;
            }
        }

        public void SetLowLatencyTrackingActive(bool value)
        {
            UnityHoloKit_SetLowLatencyTrackingApiActive(value);
        }

        public iOSThermalState GetThermalState()
        {
            return (iOSThermalState)UnityHoloKit_GetThermalState();
        }
    }
}