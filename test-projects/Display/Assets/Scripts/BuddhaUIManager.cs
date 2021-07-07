using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MLAPI;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

public class BuddhaUIManager : MonoBehaviour
{
    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Text m_IsSynced;

    private Button m_XrModeButton;

    private Button m_ArModeButton;

    [SerializeField] private GameObject m_Volume;

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    void Start()
    {
        m_StartHostButton = transform.GetChild(0).GetComponent<Button>();
        m_StartHostButton.onClick.AddListener(StartHost);

        m_StartClientButton = transform.GetChild(1).GetComponent<Button>();
        m_StartClientButton.onClick.AddListener(StartClient);

        m_IsSynced = transform.GetChild(2).GetComponent<Text>();

        m_XrModeButton = transform.GetChild(3).GetComponent<Button>();
        m_XrModeButton.onClick.AddListener(StartXrMode);

        m_ArModeButton = transform.GetChild(4).GetComponent<Button>();
        m_ArModeButton.onClick.AddListener(StartArMode);

        DisableRenderingButtons();
    }

    private void Update()
    {
        if (UnityEngine.XR.HoloKit.ARWorldOriginManager.Instance.IsARWorldMapSynced)
        {
            m_IsSynced.text = "Synced";
        }
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
        DisableNetworkButtons();
        EnableRenderingButtons();
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
        DisableNetworkButtons();
    }

    private void StartXrMode()
    {
        UnityHoloKit_SetRenderingMode(2);
        Camera.main.GetComponent<ARCameraBackground>().enabled = false;
        m_Volume.SetActive(true);
    }

    private void StartArMode()
    {
        UnityHoloKit_SetRenderingMode(1);
        Camera.main.GetComponent<ARCameraBackground>().enabled = true;
        m_Volume.SetActive(false);
    }

    private void DisableNetworkButtons()
    {
        m_StartHostButton.gameObject.SetActive(false);
        m_StartClientButton.gameObject.SetActive(false);
    }

    private void EnableRenderingButtons()
    {
        m_XrModeButton.gameObject.SetActive(true);
        m_ArModeButton.gameObject.SetActive(true);
    }

    private void DisableRenderingButtons()
    {
        m_XrModeButton.gameObject.SetActive(false);
        m_ArModeButton.gameObject.SetActive(false);
    }
}
