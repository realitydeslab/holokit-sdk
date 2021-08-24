using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using UnityEngine.XR.HoloKit;
using UnityEngine.XR.ARFoundation;
using MLAPI;
using MLAPI.Transports.MultipeerConnectivity;

public class HoloKitGameManager : MonoBehaviour
{
    private static HoloKitGameManager _instance;

    public static HoloKitGameManager Instance { get { return _instance; } }

    protected bool m_IsHost = false;

    [HideInInspector]
    public bool IsSpectator = false;

    private Button m_StartButton;

    private Text m_ConnectedClientsText;

    private Text m_SyncedClientsText;

    private Text m_ConnectedToHostText;

    private Text m_SyncedToHostText;

    private Button m_XRButton;

    private Button m_QuitButton;

    private int m_ConnectedClientsNum = 0;

    private int m_SyncedClientsNum = 0;

    private bool m_IsUISetup = false;

    private ARSession m_ARSession;

    [SerializeField]
    private string m_SceneName;

    /// <summary>
    /// Whether the host has pressed the start button?
    /// </summary>
    protected bool m_IsGameStarted = false;

    public bool IsGameStarted => m_IsGameStarted;

    protected bool m_IsNetworkStarted = false;

    [DllImport("__Internal")]
    public static extern void sendMessageToMobileApp(string message);

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern bool UnityHoloKit_SetRenderingMode(int val);

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
        Debug.Log("[HoloKitGameManager]: Start begin");
        // WEIRD: If I don't do this, the world origin won't get ret after re-entering Unity.
        m_ARSession = FindObjectOfType<ARSession>();
        m_ARSession.Reset();

        m_StartButton = transform.GetChild(0).GetComponent<Button>();
        m_StartButton.onClick.AddListener(StartGame);

        m_ConnectedClientsText = transform.GetChild(1).GetComponent<Text>();
        m_SyncedClientsText = transform.GetChild(2).GetComponent<Text>();

        m_ConnectedToHostText = transform.GetChild(3).GetComponent<Text>();
        m_SyncedToHostText = transform.GetChild(4).GetComponent<Text>();

        m_XRButton = transform.GetChild(5).GetComponent<Button>();
        m_XRButton.onClick.AddListener(SwitchRenderingMode);

        m_QuitButton = transform.GetChild(6).GetComponent<Button>();
        m_QuitButton.onClick.AddListener(QuitUnity);

        m_StartButton.gameObject.SetActive(false);
        m_ConnectedClientsText.gameObject.SetActive(false);
        m_SyncedClientsText.gameObject.SetActive(false);
        m_ConnectedToHostText.gameObject.SetActive(false);
        m_SyncedToHostText.gameObject.SetActive(false);

        Debug.Log("[HoloKitGameManager]: Start end");
        sendMessageToMobileApp("NetworkMode");
    }

    protected virtual void Update()
    {
        if (!m_IsNetworkStarted) return;

        // We no longer need to update the lobby information if the game has already started.
        if (m_IsGameStarted) return;

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

    /// <summary>
    /// This function is only called on the host side.
    /// </summary>
    private void StartGame()
    {
        if (m_SyncedClientsNum < m_ConnectedClientsNum)
        {
            Debug.Log("[HoloKitGameManager]: Please wait all clients to be synced before game starts.");
            return;
        }
        
        Handheld.Vibrate();
        if (!m_IsGameStarted)
        {
            m_IsGameStarted = true;
            m_StartButton.gameObject.SetActive(false);
            m_ConnectedClientsText.gameObject.SetActive(false);
            m_SyncedClientsText.gameObject.SetActive(false);

            // BETA: Stop advertising as the server.
            MultipeerConnectivityTransport.UnityHoloKit_MultipeerStopAdvertising();
        }

        // Switch to XR mode and start the NFC verification session.
        SwitchRenderingMode();
    }

    public void StartAsClient()
    {
        m_ConnectedToHostText.gameObject.SetActive(false);
        m_SyncedToHostText.gameObject.SetActive(false);
    }

    /// <summary>
    /// Set m_Identity string before calling this function.
    /// </summary>
    /// <param name="networkRole">Whether this is a host, client or spectator.</param>
    public virtual void StartNetwork(string networkMode)
    {
        Debug.Log("StartNewtork()");

        if (m_SceneName == null)
        {
            return;
        }

        MultipeerConnectivityTransport.Instance.IdentityString = m_SceneName;

        if (networkMode.Equals("single"))
        {
            NetworkManager.Singleton.StartHost();
            // Start game without waiting for other players to join.
            StartGame();
        }
        else if (networkMode.Equals("host"))
        {
            NetworkManager.Singleton.StartHost();;
        }
        else if (networkMode.Equals("client"))
        {
            NetworkManager.Singleton.StartClient();
        }
        m_IsNetworkStarted = true;
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            if(UnityHoloKit_SetRenderingMode(2))
            {
                Camera.main.GetComponent<ARCameraBackground>().enabled = false;
                m_XRButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
            }
            //m_Volume.SetActive(true);
            //m_Reticle.SetActive(true);
        }
        else
        {
            // Switch to AR mode.
            if (UnityHoloKit_SetRenderingMode(1))
            {
                Camera.main.GetComponent<ARCameraBackground>().enabled = true;
                m_XRButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
            }
            //m_Volume.SetActive(false);
            //m_Reticle.SetActive(false);
        }
    }

    private void Disconnect()
    {
        if (NetworkManager.Singleton.IsHost)
        {
            NetworkManager.Singleton.StopHost();
        }
        else if (NetworkManager.Singleton.IsServer)
        {
            NetworkManager.Singleton.StopServer();
        }
        else if (NetworkManager.Singleton.IsClient)
        {
            NetworkManager.Singleton.StopClient();
        }
    }

    private void QuitUnity()
    {
        Debug.Log("[HoloKitGameManager]: QuitUnity()");
        // Disconnect Multipeer Connectivity
        Disconnect();
        // Back to the void scene
        SceneManager.LoadScene("Void", LoadSceneMode.Single);
        // Hide Unity
        Gatekeeper.sendMessageToMobileApp("QuitUnity");
    }

    private void Reset()
    {
        if (m_ARSession)
        {
            m_ARSession.Reset();
        }
    }
}
