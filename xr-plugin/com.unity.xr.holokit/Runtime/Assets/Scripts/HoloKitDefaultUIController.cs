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

        private Button m_BackButton;

        private Button m_RecordButton;

        private Button m_LLTButton;

        private Button m_XRButton;

        /// <summary>
        /// The invisible button that toggles system debug info.
        /// </summary>
        private Button m_InvisibleSystemStatusButton;

        private Text m_FPS;

        private Text m_Timer;

        private Text m_Ping;

        private Text m_ThermalStatus;

        private const float k_ThermalFetchInterval = 3f;

        private float m_LastThermalFetchTime = 0f;

        private iOSThermalState m_CurrentThermalState = iOSThermalState.ThermalStateNominal;

        [SerializeField] private AudioClip m_ThermalFairSound;

        [SerializeField] private AudioClip m_ThermalSeriousSound;

        [SerializeField] private AudioClip m_TapSound;

        private GameObject m_LogWindow;

        private Button m_InvisibleLogButton;

        private Button m_InvisibleControlsButton;

        [SerializeField] private Text m_LogText;

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
            Application.logMessageReceived += HandleLog;
        }

        private void OnDisable()
        {
            Application.logMessageReceived -= HandleLog;
        }

        private void Start()
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

        private void Update()
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

        private void Back()
        {

        }

        private void ToggleRecord()
        {

        }

        private void ToggleLLT()
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

        private void ToggleXR()
        {
            if (!HoloKitSettings.Instance.IsStereoscopicRendering)
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
            if (m_FPS.gameObject.activeSelf)
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