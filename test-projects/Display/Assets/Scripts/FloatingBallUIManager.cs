using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MLAPI;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using MLAPI.Transports.MultipeerConnectivity;
using UnityEngine.XR.HoloKit;

public class FloatingBallUIManager : MonoBehaviour
{
    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Text m_IsSynced;

    private Button m_XrModeButton;

    private Button m_ArModeButton;

    private Button m_SpawnFloatingBallButton;

    private Text m_ClientId;

    private Button m_GameStartButton;

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

        m_SpawnFloatingBallButton = transform.GetChild(5).GetComponent<Button>();
        m_SpawnFloatingBallButton.onClick.AddListener(SpawnFloatingBall);

        m_ClientId = transform.GetChild(6).GetComponent<Text>();

        m_GameStartButton = transform.GetChild(7).GetComponent<Button>();
        m_GameStartButton.onClick.AddListener(GameStart);

        DisableRenderingButtons();
        m_SpawnFloatingBallButton.gameObject.SetActive(false);
        m_GameStartButton.gameObject.SetActive(false);
    }

    private void Update()
    {
        m_ClientId.text = MultipeerConnectivityTransport.Instance.ClientId.ToString();
        if (UnityEngine.XR.HoloKit.ARWorldOriginManager.Instance.IsARWorldMapSynced)
        {
            m_IsSynced.text = "Synced";
        }
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
        //HoloKitSettings.Instance.EnablePlaneDetection(true);
        HoloKitSettings.Instance.EnableMeshing(true);
        DisableNetworkButtons();
        EnableRenderingButtons();
        //m_SpawnFloatingBallButton.gameObject.SetActive(true);
        m_GameStartButton.gameObject.SetActive(true);
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
        DisableNetworkButtons();
        EnableRenderingButtons();
        m_GameStartButton.gameObject.SetActive(true);
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

    private void SpawnFloatingBall()
    {
        Debug.Log("[FloatingBallUIManager]: currently connected clients are:");
        foreach (ulong key in NetworkManager.Singleton.ConnectedClients.Keys)
        {
            Debug.Log(key);
        }
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkedClient))
        {
            var player = networkedClient.PlayerObject.GetComponent<FloatingBallPlayer>();
            if (player)
            {
                player.SpawnFloatingBall();
            }
        }
    }

    private void GameStart()
    {
        m_GameStartButton.gameObject.SetActive(false);
        if (NetworkManager.Singleton.IsHost)
        {
            m_SpawnFloatingBallButton.gameObject.SetActive(true);
        }
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkedClient))
        {
            var player = networkedClient.PlayerObject.GetComponent<FloatingBallPlayer>();
            if (player)
            {
                player.SpawnHandSphere();
            }
        }
    }
}
