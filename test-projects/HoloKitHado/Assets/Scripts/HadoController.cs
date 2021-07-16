using UnityEngine;
using System;
using System.Runtime.InteropServices;

public class HadoController : MonoBehaviour
{
    // This class is a singleton.
    private static HadoController _instance;

    public static HadoController Instance { get { return _instance; } }

    private bool m_IsGameStarted = false;

    /// <summary>
    /// If the player has tapped the start game button?
    /// After the game starts, the system will spawn the petal shield and the player can shoot bullets.
    /// The reticle will also be visible.
    /// </summary>
    public bool isGameStarted
    {
        get => m_IsGameStarted;
        set
        {
            m_IsGameStarted = value;
        }
    }

    private HadoControllerState m_CurrentControllerState = HadoControllerState.Nothing;

    /// <summary>
    /// The current state of the Apple Watch controller.
    /// </summary>
    public HadoControllerState currentControllerState
    {
        get => m_CurrentControllerState;
        set
        {
            m_CurrentControllerState = value;
        }
    }
    
    private HadoControllerAction m_NextControllerAction = HadoControllerAction.Nothing;

    /// <summary>
    /// The next pending actino of the Apple Watch controller.
    /// </summary>
    public HadoControllerAction nextControllerAction
    {
        get => m_NextControllerAction;
        set
        {
            m_NextControllerAction = value;
        }
    }

    private float m_CurrentAttackRecharge = 0f;

    private const float k_AttackRechargeUnit = 1f;

    private const float k_AttackRechargeSpeed = 0.016f;

    private const float k_MaxAttackRecharge = 5f;

    private int m_CurrentAttackNum = 0;

    /// <summary>
    /// The current remaining number of attacks which can be used.
    /// </summary>
    public int currentAttackNum
    {
        get => m_CurrentAttackNum;
    }

    public float currentAttackRechargePercent
    {
        get => m_CurrentAttackRecharge / k_MaxAttackRecharge;
    }

    private float m_CurrentShieldRecharge = 0f;

    private const float k_ShieldRechargeUnit = 3f;

    private const float k_ShieldRechargeSpeed = 0.016f;

    private const float k_MaxShieldRecharge = 6f;

    private int m_CurrentShieldNum = 0;

    /// <summary>
    /// The current remaining number of giant shields which can be used.
    /// </summary>
    public int currentShieldNum
    {
        get => m_CurrentShieldNum;
    }

    public float currentShieldRechargePercent
    {
        get => m_CurrentShieldRecharge / k_MaxShieldRecharge;
    }

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_BulletRechargedAudioClip;

    [SerializeField] private AudioClip m_ShieldRechargedAudioClip;

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_ActivateWatchConnectivitySession();

    /// <summary>
    /// This delegate function is called when a new message from Apple Watch is received.
    /// </summary>
    /// <param name="messageIndex">The type of the message from Apple Watch.</param>
    delegate void AppleWatchMessageReceived(int messageIndex);
    [AOT.MonoPInvokeCallback(typeof(AppleWatchMessageReceived))]
    static void OnAppleWatchMessageReceived(int messageIndex)
    {
        switch ((AppleWatchMessageType)messageIndex)
        {
            case (AppleWatchMessageType.StartGame):
                //Debug.Log("[HadoController]: start game");
                Instance.isGameStarted = true;
                break;
            case (AppleWatchMessageType.Fire):
                //Debug.Log("[HadoController]: fire");
                Instance.nextControllerAction = HadoControllerAction.Fire;
                break;
            case (AppleWatchMessageType.CastShield):
                //Debug.Log("[HadoController]: cast shield");
                Instance.nextControllerAction = HadoControllerAction.CastShield;
                break;
            case (AppleWatchMessageType.StateChangedToNothing):
                //Debug.Log("[HadoController]: state changed to nothing");
                Instance.currentControllerState = HadoControllerState.Nothing;
                break;
            case (AppleWatchMessageType.StateChangedToUp):
                //Debug.Log("[HadoController]: state changed to up");
                Instance.currentControllerState = HadoControllerState.Up;
                break;
            case (AppleWatchMessageType.StateChangedToDown):
                //Debug.Log("[HadoController]: state changed to down");
                Instance.currentControllerState = HadoControllerState.Down;
                break;
            default:
                break;
        }
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetAppleWatchMessageReceivedDelegate(AppleWatchMessageReceived callback);

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
        // Register delegates
        UnityHoloKit_SetAppleWatchMessageReceivedDelegate(OnAppleWatchMessageReceived);
    }

    private void Start()
    {
        //UnityHoloKit_ActivateWatchConnectivitySession();
        m_AudioSource = GetComponent<AudioSource>();
    }

    private void FixedUpdate()
    {
        if (m_CurrentControllerState == HadoControllerState.Nothing)
        {
            // The energy doesn't decrease when not charging.
            return;
        }

        if (m_CurrentControllerState == HadoControllerState.Up)
        {
            m_CurrentAttackRecharge += k_AttackRechargeSpeed;
            if (m_CurrentAttackRecharge > k_MaxAttackRecharge)
            {
                m_CurrentAttackRecharge = k_MaxAttackRecharge;
            }

            if (m_CurrentAttackNum < (int)Math.Floor(m_CurrentAttackRecharge / k_AttackRechargeUnit))
            {
                m_AudioSource.clip = m_BulletRechargedAudioClip;
                m_AudioSource.Play();
                m_CurrentAttackNum++;
            }
            return;
        }
        
        if (m_CurrentControllerState == HadoControllerState.Down)
        {
            m_CurrentShieldRecharge += k_ShieldRechargeSpeed;
            if (m_CurrentShieldRecharge > k_MaxShieldRecharge)
            {
                m_CurrentShieldRecharge = k_MaxShieldRecharge;
            }

            if (m_CurrentShieldNum < (int)Math.Floor(m_CurrentShieldRecharge / k_ShieldRechargeUnit))
            {
                Debug.Log("[HadoController]: shield recharged");
                m_AudioSource.clip = m_ShieldRechargedAudioClip;
                m_AudioSource.Play();
                m_CurrentShieldNum++;
            }
            return;
        }

        if (m_CurrentControllerState == HadoControllerState.Nothing)
        {
            m_CurrentAttackRecharge = m_CurrentAttackNum * k_AttackRechargeUnit;
            m_CurrentShieldRecharge = m_CurrentShieldNum * k_ShieldRechargeUnit;
        }
    }

    /// <summary>
    /// This method should be called every time the player takes an attack action.
    /// </summary>
    public void AfterAttack()
    {
        m_CurrentAttackRecharge -= k_AttackRechargeUnit;
        m_CurrentAttackNum--;
    }

    /// <summary>
    /// This method should be called every time the players takes an cast shield action.
    /// </summary>
    public void AfterCastShield()
    {
        m_CurrentShieldRecharge -= k_ShieldRechargeUnit;
        m_CurrentShieldNum--;
    }
}