using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitDefaultUIController : MonoBehaviour
    {
        private static HoloKitDefaultUIController _instance;

        public static HoloKitDefaultUIController Instance { get { return _instance; } }

        protected Button m_BackButton;

        protected Button m_RecordButton;

        protected Button m_LLTButton;

        protected Button m_XRButton;

        /// <summary>
        /// The invisible button that toggles system debug info.
        /// </summary>
        protected Button m_InvisibleSystemStatusButton;

        protected Text m_FPS;

        protected Text m_Timer;

        protected Text m_Ping;

        protected Text m_ThermalStatus;

        protected const float k_ThermalFetchInterval = 3f;

        protected float m_LastThermalFetchTime = 0f;

        protected iOSThermalState m_CurrentThermalState = iOSThermalState.ThermalStateNominal;

        [SerializeField] protected AudioClip m_ThermalFairSound;

        [SerializeField] protected AudioClip m_ThermalSeriousSound;

        [SerializeField] protected AudioClip m_TapSound;

        private GameObject m_LogWindow;

        private Button m_InvisibleLogButton;

        private Button m_InvisibleControlsButton;

        [SerializeField] private Text m_LogText;

        protected virtual void Awake()
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

        protected virtual void OnEnable()
        {
            Application.logMessageReceived += HandleLog;
        }

        protected virtual void OnDisable()
        {
            Application.logMessageReceived -= HandleLog;
        }

        protected virtual void Start()
        {
            Transform backButton = transform.Find("Back Button");
            if (backButton)
            {
                m_BackButton = backButton.GetComponent<Button>();
                m_BackButton.onClick.AddListener(Back);
            }

            Transform recordButton = transform.Find("Record Button");
            if (recordButton)
            {
                m_RecordButton = recordButton.GetComponent<Button>();
                m_RecordButton.onClick.AddListener(ToggleRecord);
            }

            Transform lltButton = transform.Find("LLT Button");
            if (lltButton)
            {
                m_LLTButton = lltButton.GetComponent<Button>();
                m_LLTButton.onClick.AddListener(ToggleLLT);
            }

            Transform xrButton = transform.Find("XR Button");
            if (xrButton)
            {
                m_XRButton = xrButton.GetComponent<Button>();
                m_XRButton.onClick.AddListener(ToggleXR);
            }

            Transform invisibleButton = transform.Find("Invisible Status Button");
            if (invisibleButton)
            {
                m_InvisibleSystemStatusButton = invisibleButton.GetComponent<Button>();
                m_InvisibleSystemStatusButton.onClick.AddListener(ToggleSystemStatus);
            }

            m_FPS = transform.Find("FPS").GetComponent<Text>();
            m_Timer = transform.Find("Timer").GetComponent<Text>();
            m_Ping = transform.Find("Ping").GetComponent<Text>();
            m_ThermalStatus = transform.Find("Thermal Status").GetComponent<Text>();

            m_LogWindow = transform.Find("Log Window").gameObject;
            m_InvisibleLogButton = transform.Find("Invisible Log Button").GetComponent<Button>();
            m_InvisibleLogButton.onClick.AddListener(ToggleLog);
            m_InvisibleControlsButton = transform.Find("Invisible Controls Button").GetComponent<Button>();
            m_InvisibleControlsButton.onClick.AddListener(ToggleButtons);
        }

        protected virtual void Update()
        {
            // Display current thermal status
            if (m_ThermalStatus.enabled)
            {
                if (Time.time - m_LastThermalFetchTime > k_ThermalFetchInterval)
                {
                    m_LastThermalFetchTime = Time.time;
                    var currentThermalState = UnityEngine.XR.HoloKit.HoloKitSettings.Instance.GetThermalState();
                    switch (currentThermalState)
                    {
                        case iOSThermalState.ThermalStateNominal:
                            m_ThermalStatus.text = "Normal";
                            m_ThermalStatus.color = Color.blue;
                            m_CurrentThermalState = iOSThermalState.ThermalStateNominal;
                            break;
                        case iOSThermalState.ThermalStateFair:
                            m_ThermalStatus.text = "Fair";
                            m_ThermalStatus.color = Color.green;
                            if (m_CurrentThermalState == iOSThermalState.ThermalStateNominal)
                            {
                                if (m_ThermalFairSound)
                                {
                                    var audioSource = GetComponent<AudioSource>();
                                    audioSource.clip = m_ThermalFairSound;
                                    audioSource.Play();
                                }
                            }
                            m_CurrentThermalState = iOSThermalState.ThermalStateFair;
                            break;
                        case iOSThermalState.ThermalStateSerious:
                            m_ThermalStatus.text = "Serious";
                            m_ThermalStatus.color = Color.yellow;
                            if (m_CurrentThermalState == iOSThermalState.ThermalStateFair)
                            {
                                if (m_ThermalSeriousSound)
                                {
                                    var audioSource = GetComponent<AudioSource>();
                                    audioSource.clip = m_ThermalSeriousSound;
                                    audioSource.Play();
                                }
                            }
                            m_CurrentThermalState = iOSThermalState.ThermalStateSerious;
                            break;
                        case iOSThermalState.ThermalStateCritical:
                            m_ThermalStatus.text = "Critical";
                            m_ThermalStatus.color = Color.red;
                            m_CurrentThermalState = iOSThermalState.ThermalStateCritical;
                            break;
                    }
                }
            }
        }

        protected virtual void Back()
        {

        }

        protected virtual void ToggleRecord()
        {

        }

        protected virtual void ToggleLLT()
        {
            if (HoloKitSettings.Instance.LowLatencyTrackingActive)
            {
                HoloKitSettings.Instance.SetLowLatencyTrackingActive(false);
                m_LLTButton.transform.Find("Text").GetComponent<Text>().text = "LLT Off";
            }
            else
            {
                HoloKitSettings.Instance.SetLowLatencyTrackingActive(true);
                m_LLTButton.transform.Find("Text").GetComponent<Text>().text = "LLT On";
            }
        }

        protected virtual void ToggleXR()
        {
            if (!HoloKitSettings.Instance.StereoscopicRendering)
            {
                if (HoloKitSettings.Instance.SetStereoscopicRendering(true))
                {
                    m_XRButton.transform.Find("Text").GetComponent<Text>().text = "AR";
                }
            }
            else
            {
                if (HoloKitSettings.Instance.SetStereoscopicRendering(false))
                {
                    m_XRButton.transform.Find("Text").GetComponent<Text>().text = "XR";
                }
            }
        }

        private void ToggleSystemStatus()
        {
            if (m_ThermalStatus.enabled)
            {
                m_FPS.gameObject.SetActive(false);
                m_Timer.gameObject.SetActive(false);
                m_Ping.gameObject.SetActive(false);
                m_ThermalStatus.gameObject.SetActive(false);
            }
            else
            {
                m_FPS.gameObject.SetActive(true);
                m_Timer.gameObject.SetActive(true);
                m_Ping.gameObject.SetActive(true);
                m_ThermalStatus.gameObject.SetActive(true);
            }
        }

        private void ToggleButtons()
        {
            if (m_BackButton.gameObject.activeSelf)
            {
                m_BackButton.gameObject.SetActive(false);
                m_LLTButton.gameObject.SetActive(false);
                m_XRButton.gameObject.SetActive(false);
            }
            else
            {
                m_BackButton.gameObject.SetActive(true);
                m_LLTButton.gameObject.SetActive(true);
                m_XRButton.gameObject.SetActive(true);
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
    }
}