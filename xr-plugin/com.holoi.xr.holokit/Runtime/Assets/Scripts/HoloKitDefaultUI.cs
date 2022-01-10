using UnityEngine.UI;
using UnityEngine.Events;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitDefaultUI : MonoBehaviour
    {
        [SerializeField] private Button m_StARButton;

        [SerializeField] private Text m_FPS;

        [SerializeField] private Text m_Timer;

        [SerializeField] private Text m_ThermalState;

        [SerializeField] private Text m_CameraTrackingState;

        public event UnityAction<bool> InvisibleButtonPressedEvent;

        private void Start()
        {
            OnThermalStateDidChange(HoloKitManager.Instance.GetThermalState());
            HoloKitManager.Instance.ThermalStateDidChangeEvent += OnThermalStateDidChange;
            HoloKitManager.Instance.CameraDidChangeTrackingStateEvent += OnCameraDidChangeTrackingState;
            HoloKitManager.Instance.DidChange2StAREvent += OnDidChange2StAR;
            HoloKitManager.Instance.DidChange2AREvent += OnDidChange2AR;
        }

        private void OnDisable()
        {
            HoloKitManager.Instance.ThermalStateDidChangeEvent -= OnThermalStateDidChange;
            HoloKitManager.Instance.CameraDidChangeTrackingStateEvent -= OnCameraDidChangeTrackingState;
            HoloKitManager.Instance.DidChange2StAREvent -= OnDidChange2StAR;
            HoloKitManager.Instance.DidChange2AREvent -= OnDidChange2AR;
        }

        private void OnDidChange2StAR()
        {
            m_StARButton.transform.Find("Text").GetComponent<Text>().text = "AR";
        }

        private void OnDidChange2AR()
        {
            m_StARButton.transform.Find("Text").GetComponent<Text>().text = "StAR";
        }

        public void ToggleStAR()
        {
            if (!HoloKitManager.Instance.IsStereoscopicRendering)
            {
                HoloKitManager.Instance.TurnOnStereoscopicRendering();
            }
            else
            {
                HoloKitManager.Instance.TurnOffStereoscopicRendering();
            }
        }

        public void ToggleUI()
        {
            if (m_StARButton.gameObject.activeSelf)
            {
                m_StARButton.gameObject.SetActive(false);
                m_FPS.gameObject.SetActive(false);
                m_Timer.gameObject.SetActive(false);
                m_ThermalState.gameObject.SetActive(false);
                m_CameraTrackingState.gameObject.SetActive(false);
                InvisibleButtonPressedEvent?.Invoke(false);
            }
            else
            {
                m_StARButton.gameObject.SetActive(true);
                m_FPS.gameObject.SetActive(true);
                m_Timer.gameObject.SetActive(true);
                m_ThermalState.gameObject.SetActive(true);
                m_CameraTrackingState.gameObject.SetActive(false);
                InvisibleButtonPressedEvent?.Invoke(true);
            }
        }

        private void OnThermalStateDidChange(iOSThermalState state)
        {
            if (!m_ThermalState.gameObject.activeSelf) return;

            switch (HoloKitManager.Instance.GetThermalState())
            {
                case iOSThermalState.ThermalStateNominal:
                    m_ThermalState.text = "Normal";
                    m_ThermalState.color = Color.blue;
                    break;
                case iOSThermalState.ThermalStateFair:
                    m_ThermalState.text = "Fair";
                    m_ThermalState.color = Color.green;
                    break;
                case iOSThermalState.ThermalStateSerious:
                    m_ThermalState.text = "Serious";
                    m_ThermalState.color = Color.yellow;
                    break;
                case iOSThermalState.ThermalStateCritical:
                    m_ThermalState.text = "Critical";
                    m_ThermalState.color = Color.red;
                    break;
            }
        }

        private void OnCameraDidChangeTrackingState(ARKitCameraTrackingState newTrackingState)
        {
            switch (newTrackingState)
            {
                case ARKitCameraTrackingState.NotAvailable:
                    m_CameraTrackingState.text = "Not Available";
                    break;
                case ARKitCameraTrackingState.LimitedWithReasonNone:
                    m_CameraTrackingState.text = "None";
                    break;
                case ARKitCameraTrackingState.LimitedWithReasonInitializing:
                    m_CameraTrackingState.text = "Initializing";
                    break;
                case ARKitCameraTrackingState.LimitedWithReasonExcessiveMotion:
                    m_CameraTrackingState.text = "Excessive Motion";
                    break;
                case ARKitCameraTrackingState.LimitedWithReasonInsufficientFeatures:
                    m_CameraTrackingState.text = "Insufficient Features";
                    break;
                case ARKitCameraTrackingState.LimitedWithReasonRelocalizing:
                    m_CameraTrackingState.text = "Relocalizing";
                    break;
                case ARKitCameraTrackingState.Normal:
                    m_CameraTrackingState.text = "Normal";
                    break;
            }
        }
    }
}