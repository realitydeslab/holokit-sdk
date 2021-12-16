using UnityEngine.UI;
using UnityEngine.Events;

namespace UnityEngine.XR.HoloKit
{
    public class ARDefaultUI : MonoBehaviour
    {
        private Button m_LLTButton;

        private Button m_XRButton;

        private Button m_InvisibleButton;

        private Button m_BackButton;

        private Text m_FPS;

        private Text m_Timer;

        private Text m_Ping;

        private Text m_ThermalState;

        [SerializeField] private AudioClip m_ThermalFairSound;

        [SerializeField] private AudioClip m_ThermalSeriousSound;

        [SerializeField] private AudioClip m_TapSound;

        private GameObject m_LogWindow;

        private Button m_InvisibleLogButton;

        [SerializeField] private Text m_LogText;

        public event UnityAction<bool> InvisibleButtonPressedEvent;

        private void OnEnable()
        {
            Application.logMessageReceived += HandleLog;
            HoloKitManager.Instance.ThermalStateDidChangeEvent += OnThermalStateDidChange;
        }

        private void OnDisable()
        {
            Application.logMessageReceived -= HandleLog;
            HoloKitManager.Instance.ThermalStateDidChangeEvent -= OnThermalStateDidChange;
        }

        private void Start()
        {
            m_XRButton = transform.Find("XR Button").GetComponent<Button>();
            m_XRButton.onClick.AddListener(ToggleXR);

            m_LLTButton = transform.Find("LLT Button").GetComponent<Button>();
            m_LLTButton.onClick.AddListener(ToggleLLT);

            m_InvisibleButton = transform.Find("Invisible Button").GetComponent<Button>();
            m_InvisibleButton.onClick.AddListener(ToggleUI);

            m_BackButton = transform.Find("Quit Button").GetComponent<Button>();

            m_FPS = transform.Find("FPS").GetComponent<Text>();
            m_Timer = transform.Find("Timer").GetComponent<Text>();
            //m_Ping = transform.Find("Ping").GetComponent<Text>();
            m_ThermalState = transform.Find("Thermal State").GetComponent<Text>();

            m_LogWindow = transform.Find("Log Window").gameObject;
            m_InvisibleLogButton = transform.Find("Invisible Log Button").GetComponent<Button>();
            m_InvisibleLogButton.onClick.AddListener(ToggleLog);

            OnThermalStateDidChange((int)HoloKitManager.Instance.GetThermalState());
        }

        private void ToggleLLT()
        {
            if (m_TapSound)
            {
                var audioSource = GetComponent<AudioSource>();
                audioSource.clip = m_TapSound;
                audioSource.Play();
            }

            if (HoloKitManager.Instance.LowLatencyTrackingActive)
            {
                HoloKitManager.Instance.SetLowLatencyTrackingActive(false);
                m_LLTButton.transform.Find("Text").GetComponent<Text>().text = "LLT Off";
            }
            else
            {
                HoloKitManager.Instance.SetLowLatencyTrackingActive(true);
                m_LLTButton.transform.Find("Text").GetComponent<Text>().text = "LLT On";
            }
        }

        private void ToggleXR()
        {
            if (m_TapSound)
            {
                var audioSource = GetComponent<AudioSource>();
                audioSource.clip = m_TapSound;
                audioSource.Play();
            }

            if (!HoloKitManager.Instance.IsStereoscopicRendering)
            {
                if (HoloKitManager.Instance.EnableStereoscopicRendering(true))
                {
                    m_XRButton.transform.Find("Text").GetComponent<Text>().text = "AR";
                }
            }
            else
            {
                if (HoloKitManager.Instance.EnableStereoscopicRendering(false))
                {
                    m_XRButton.transform.Find("Text").GetComponent<Text>().text = "StAR";
                }
            }
        }

        private void ToggleUI()
        {
            if (m_FPS.gameObject.activeSelf)
            {
                m_FPS.gameObject.SetActive(false);
                m_Timer.gameObject.SetActive(false);
                //m_Ping.gameObject.SetActive(false);
                m_ThermalState.gameObject.SetActive(false);
                m_LLTButton.gameObject.SetActive(false);
                m_XRButton.gameObject.SetActive(false);
                m_BackButton.gameObject.SetActive(false);
                InvisibleButtonPressedEvent?.Invoke(false);
            }
            else
            {
                m_FPS.gameObject.SetActive(true);
                m_Timer.gameObject.SetActive(true);
                //m_Ping.gameObject.SetActive(true);
                m_ThermalState.gameObject.SetActive(true);
                m_LLTButton.gameObject.SetActive(true);
                m_XRButton.gameObject.SetActive(true);
                m_BackButton.gameObject.SetActive(true);
                InvisibleButtonPressedEvent?.Invoke(true);
            }
        }

        private void ToggleLog()
        {
            if (m_LogWindow.activeSelf)
            {
                m_LogWindow.SetActive(false);
            }
            else
            {
                m_LogWindow.SetActive(true);
            }
        }

        private void HandleLog(string logString, string stackTrace, LogType type)
        {
            string currentLog = "\n[" + type + "]: " + logString + "\n" + stackTrace;

            m_LogText.text += currentLog;
            // The max length is 25990 or something.
            if (m_LogText.text.Length > 10000)
            {
                m_LogText.text = m_LogText.text.Substring(5000);
            }
        }

        private void OnThermalStateDidChange(int state)
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
                    if (m_ThermalFairSound)
                    {
                        var audioSource = GetComponent<AudioSource>();
                        audioSource.clip = m_ThermalFairSound;
                        audioSource.Play();
                    }
                    break;
                case iOSThermalState.ThermalStateSerious:
                    m_ThermalState.text = "Serious";
                    m_ThermalState.color = Color.yellow;
                    if (m_ThermalSeriousSound)
                    {
                        var audioSource = GetComponent<AudioSource>();
                        audioSource.clip = m_ThermalSeriousSound;
                        audioSource.Play();
                    }
                    break;
                case iOSThermalState.ThermalStateCritical:
                    m_ThermalState.text = "Critical";
                    m_ThermalState.color = Color.red;
                    break;
            }
        }
    }
}