using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;
using MLAPI;
using MLAPI.Connection;
using System.Runtime.InteropServices;

public class HadoUIManager : MonoBehaviour
{
    // This class is a singleton.
    private static HadoUIManager _instance;

    public static HadoUIManager Instance { get { return _instance; } }

    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Button m_StartSpectatorButton;

    private Button m_SwitchRenderingModeButton;

    private Text m_Connection;

    private Text m_Sync;

    private bool m_IsConnected;

    private bool m_IsSynced;

    [SerializeField] private GameObject m_Volume;

    [SerializeField] private GameObject m_Reticle;

    private bool m_IsSpectator = false;

    public bool IsSpectator
    {
        get => m_IsSpectator;
    }

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    /// <summary>
    /// This delegate function gets called when the Apple Watch reachability
    /// changes on the Objective-C side.
    /// </summary>
    /// <param name="isReachable">Is Apple Watch reachable?</param>
    delegate void AppleWatchReachabilityDidChange(bool isReachable);
    [AOT.MonoPInvokeCallback(typeof(AppleWatchReachabilityDidChange))]
    static void OnAppleWatchReachabilityDidChange(bool isReachable)
    {
        if (isReachable)
        {
            Debug.Log("[HadoUIManager]: Apple Watch reachability changed to reachable");
        }
        else
        {
            Debug.Log("[HadoUIManager]: Apple Watch reachability changed to not reachable");
        }
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetAppleWatchReachabilityDidChangeDelegate(AppleWatchReachabilityDidChange callback);

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
        UnityHoloKit_SetAppleWatchReachabilityDidChangeDelegate(OnAppleWatchReachabilityDidChange);
    }

    private void Start()
    {
        m_StartHostButton = transform.GetChild(0).GetComponent<Button>();
        m_StartHostButton.onClick.AddListener(StartHost);

        m_StartClientButton = transform.GetChild(1).GetComponent<Button>();
        m_StartClientButton.onClick.AddListener(StartClient);

        m_StartSpectatorButton = transform.GetChild(2).GetComponent<Button>();
        m_StartSpectatorButton.onClick.AddListener(StartSpectator);

        m_SwitchRenderingModeButton = transform.GetChild(3).GetComponent<Button>();
        m_SwitchRenderingModeButton.onClick.AddListener(SwitchRenderingMode);

        m_Connection = transform.GetChild(4).GetComponent<Text>();
        m_Sync = transform.GetChild(5).GetComponent<Text>();
    }

    private void Update()
    {
        if (!m_IsConnected)
        {
            if (NetworkManager.Singleton.IsServer)
            {
                if (NetworkManager.Singleton.ConnectedClients.Count > 1)
                {
                    m_Connection.text = "Connected";
                    m_IsConnected = true;
                }
            }
            else
            {
                if (NetworkManager.Singleton.ConnectedClients.Count > 0)
                {
                    m_Connection.text = "Connected";
                    m_IsConnected = true;
                }
            }
        }

        if (!m_IsSynced)
        {
            if (UnityEngine.XR.HoloKit.ARWorldOriginManager.Instance.IsARWorldMapSynced)
            {
                m_Sync.text = "Synced";
                m_IsSynced = true;
            }
        }
    }

    private void StartHost()
    {
        m_IsSpectator = false;
        NetworkManager.Singleton.StartHost();
        DisableHostClientButtons();
    }

    private void StartClient()
    {
        m_IsSpectator = false;
        NetworkManager.Singleton.StartClient();
        DisableHostClientButtons();
    }

    private void StartSpectator()
    {
        m_IsSpectator = true;
        NetworkManager.Singleton.StartClient();
        DisableHostClientButtons();
    }

    private void DisableHostClientButtons()
    {
        m_StartHostButton.gameObject.SetActive(false);
        m_StartClientButton.gameObject.SetActive(false);
        m_StartSpectatorButton.gameObject.SetActive(false);
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
            m_Volume.SetActive(true);
            m_Reticle.SetActive(true);
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
            m_Volume.SetActive(false);
            m_Reticle.SetActive(false);
        }
    }

    private HadoPlayer GetLocalPlayer()
    {
        ulong localClientId = NetworkManager.Singleton.LocalClientId;
        if (!NetworkManager.Singleton.ConnectedClients.TryGetValue(localClientId, out NetworkClient networkClient))
        {
            return null;
        }
        if (!networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
        {
            return null;
        }
        return script;
    }
}
