using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Connection;
using System.Runtime.InteropServices;

public class PPvEUIManager : MonoBehaviour
{
    // This class is a singleton.
    private static PPvEUIManager _instance;

    public static PPvEUIManager Instance { get { return _instance; } }

    private Button m_StartAsBossButton;

    private Button m_StartAsPlayerButton;

    private Button m_StartAsSpectatorButton;

    private Button m_SwitchRenderingModeButton;

    private Button m_StartSpawnBossButton;

    private Button m_SpawnBossButton;

    private Button m_CancelSpawnBossButton;

    private Text m_Connection;

    private Text m_Sync;

    private bool m_IsConnected;

    private bool m_IsSynced;

    [SerializeField] private GameObject m_Volume;

    [SerializeField] private GameObject m_Reticle;

    [SerializeField] private GameObject m_BossController;

    [SerializeField] private GameObject m_PlacementIndicator;

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
        m_StartAsBossButton = transform.GetChild(0).GetComponent<Button>();
        m_StartAsBossButton.onClick.AddListener(StartAsBoss);

        m_StartAsPlayerButton = transform.GetChild(1).GetComponent<Button>();
        m_StartAsPlayerButton.onClick.AddListener(StartAsPlayer);

        m_StartAsSpectatorButton = transform.GetChild(2).GetComponent<Button>();
        m_StartAsSpectatorButton.onClick.AddListener(StartAsSpectator);

        m_SwitchRenderingModeButton = transform.GetChild(3).GetComponent<Button>();
        m_SwitchRenderingModeButton.onClick.AddListener(SwitchRenderingMode);

        m_Connection = transform.GetChild(4).GetComponent<Text>();
        m_Sync = transform.GetChild(5).GetComponent<Text>();

        m_StartSpawnBossButton = transform.GetChild(6).GetComponent<Button>();
        m_StartSpawnBossButton.onClick.AddListener(StartSpawnBoss);

        m_SpawnBossButton = transform.GetChild(7).GetComponent<Button>();
        m_SpawnBossButton.onClick.AddListener(SpawnBoss);

        m_CancelSpawnBossButton = transform.GetChild(8).GetComponent<Button>();
        m_CancelSpawnBossButton.onClick.AddListener(CancelSpawnBoss);

        m_StartSpawnBossButton.gameObject.SetActive(false);
        m_SpawnBossButton.gameObject.SetActive(false);
        m_CancelSpawnBossButton.gameObject.SetActive(false);
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

    private void StartAsBoss()
    {
        NetworkManager.Singleton.StartHost();
        DisableHostClientButtons();
        m_StartSpawnBossButton.gameObject.SetActive(true);
        HoloKitSettings.Instance.EnablePlaneDetection(true);
    }

    private void StartAsPlayer()
    {
        NetworkManager.Singleton.StartClient();
        DisableHostClientButtons();
        GetLocalPlayer().IsSpectator = false;
    }

    private void StartAsSpectator()
    {
        NetworkManager.Singleton.StartClient();
        DisableHostClientButtons();
    }

    private void DisableHostClientButtons()
    {
        m_StartAsBossButton.gameObject.SetActive(false);
        m_StartAsPlayerButton.gameObject.SetActive(false);
        m_StartAsSpectatorButton.gameObject.SetActive(false);
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

    private void StartSpawnBoss()
    {
        m_SpawnBossButton.gameObject.SetActive(true);
        m_CancelSpawnBossButton.gameObject.SetActive(true);
        // TODO: Open the ray caster
        m_PlacementIndicator.gameObject.SetActive(true);
    }

    private void SpawnBoss()
    {
        m_SpawnBossButton.gameObject.SetActive(false);
        m_CancelSpawnBossButton.gameObject.SetActive(false);
        m_BossController.gameObject.SetActive(true);
        // TODO: Spawn the boss

    }

    private void CancelSpawnBoss()
    {
        m_SpawnBossButton.gameObject.SetActive(false);
        m_CancelSpawnBossButton.gameObject.SetActive(false);
        m_StartSpawnBossButton.gameObject.SetActive(true);
        // TODO: Disable the ray caster
        m_PlacementIndicator.gameObject.SetActive(false);
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
