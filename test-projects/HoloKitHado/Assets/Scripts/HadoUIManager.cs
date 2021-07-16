using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;
using MLAPI;
using System.Runtime.InteropServices;

public class HadoUIManager : MonoBehaviour
{
    // This class is a singleton.
    private static HadoUIManager _instance;

    public static HadoUIManager Instance { get { return _instance; } }

    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Button m_SwitchRenderingModeButton;

    private Text m_Connection;

    private Text m_Sync;

    private Text m_AppleWatchReachability;

    public Text AppleWatchReachability
    {
        get => m_AppleWatchReachability;
        set
        {
            m_AppleWatchReachability = value;
        }
    }

    private bool m_IsConnected;

    private bool m_IsSynced;

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
            Instance.AppleWatchReachability.text = "Reachable";
        }
        else
        {
            Instance.AppleWatchReachability.text = "Not Reachable";
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

        m_SwitchRenderingModeButton = transform.GetChild(2).GetComponent<Button>();
        m_SwitchRenderingModeButton.onClick.AddListener(SwitchRenderingMode);

        m_Connection = transform.GetChild(3).GetComponent<Text>();
        m_Sync = transform.GetChild(4).GetComponent<Text>();
        m_AppleWatchReachability = transform.GetChild(5).GetComponent<Text>();
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
        NetworkManager.Singleton.StartHost();
        DisableHostClientButtons();
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
        DisableHostClientButtons();
    }

    private void DisableHostClientButtons()
    {
        m_StartHostButton.gameObject.SetActive(false);
        m_StartClientButton.gameObject.SetActive(false);
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
        }
    }
}
