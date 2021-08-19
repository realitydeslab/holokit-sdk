using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.HoloKit;
using UnityEngine.XR.ARFoundation;
using MLAPI;
using MLAPI.Transports.MultipeerConnectivity;

public abstract class HoloKitGameManager : MonoBehaviour
{
    private static HoloKitGameManager _instance;

    public static HoloKitGameManager Instance { get { return _instance; } }

    protected bool m_IsHost = false;

    public bool IsSpectator = false;

    private Button m_StartButton;

    private Text m_ConnectedClientsText;

    private Text m_SyncedClientsText;

    private Text m_ConnectedToHostText;

    private Text m_SyncedToHostText;

    private Button m_XRButton;

    private int m_ConnectedClientsNum = 0;

    private int m_SyncedClientsNum = 0;

    private bool m_IsUISetup = false;

    private bool m_IsGameStarted = false;

    public bool IsGameStarted => m_IsGameStarted;

    [DllImport("__Internal")]
    public static extern void sendMessageToMobileApp(string message);

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

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

    protected virtual void Start()
    {
        sendMessageToMobileApp("NetworkRole");

        m_StartButton = transform.GetChild(0).GetComponent<Button>();
        m_StartButton.onClick.AddListener(StartGame);

        m_ConnectedClientsText = transform.GetChild(1).GetComponent<Text>();
        m_SyncedClientsText = transform.GetChild(2).GetComponent<Text>();

        m_ConnectedToHostText = transform.GetChild(3).GetComponent<Text>();
        m_SyncedToHostText = transform.GetChild(4).GetComponent<Text>();

        m_XRButton = transform.GetChild(5).GetComponent<Button>();
        m_XRButton.onClick.AddListener(SwitchRenderingMode);

        m_StartButton.gameObject.SetActive(false);
        m_ConnectedClientsText.gameObject.SetActive(false);
        m_SyncedClientsText.gameObject.SetActive(false);
        m_ConnectedToHostText.gameObject.SetActive(false);
        m_SyncedToHostText.gameObject.SetActive(false);
    }

    protected virtual void Update()
    {
        if (NetworkManager.Singleton.IsServer)
        {
            if (!m_IsUISetup)
            {
                m_IsUISetup = true;
                m_StartButton.gameObject.SetActive(true);
                m_ConnectedClientsText.gameObject.SetActive(true);
                m_SyncedClientsText.gameObject.SetActive(true);
            }
            m_ConnectedClientsNum = NetworkManager.Singleton.ConnectedClients.Count - 1;
            m_SyncedClientsNum = ARWorldOriginManager.Instance.SyncedClientsNum;
            m_ConnectedClientsText.text = $"Connected clients: {m_ConnectedClientsNum}";
            m_SyncedClientsText.text = $"Synced clients: {m_SyncedClientsNum}";
        }
        else
        {
            if (!m_IsUISetup)
            {
                m_IsUISetup = true;
                m_ConnectedToHostText.gameObject.SetActive(true);
                m_SyncedToHostText.gameObject.SetActive(true);
            }
            if (NetworkManager.Singleton.ConnectedClients.Count > 0)
            {
                m_ConnectedToHostText.text = "Connected to the host";
            }
            if (ARWorldOriginManager.Instance.IsARWorldMapSynced)
            {
                m_SyncedToHostText.text = "Synced to the host";
            }
        }
    }

    protected virtual void StartGame()
    {
        if (!m_IsGameStarted)
            m_IsGameStarted = true;
    }

    /// <summary>
    /// Set m_Identity string before calling this function.
    /// </summary>
    /// <param name="networkRole">Whether this is a host, client or spectator.</param>
    public virtual void StartNetwork(string networkRole)
    {
        if (MultipeerConnectivityTransport.Instance.IdentityString == null)
        {
            return;
        }

        if (networkRole.Equals("Host"))
        {
            NetworkManager.Singleton.StartHost();
            m_IsHost = true;
        }
        else if (networkRole.Equals("Client"))
        {
            NetworkManager.Singleton.StartClient();
        }
        else if (networkRole.Equals("Spectator"))
        {
            NetworkManager.Singleton.StartClient();
            IsSpectator = true;
        }
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            m_XRButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
            //m_Volume.SetActive(true);
            //m_Reticle.SetActive(true);
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            m_XRButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
            //m_Volume.SetActive(false);
            //m_Reticle.SetActive(false);
        }
    }
}
