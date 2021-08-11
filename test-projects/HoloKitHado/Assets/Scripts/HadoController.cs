using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using MLAPI;

public class HadoController : MonoBehaviour
{
    // This class is a singleton.
    private static HadoController _instance;

    public static HadoController Instance { get { return _instance; } }

    private bool m_IsReady = false;

    /// <summary>
    /// If the player has tapped the start game button?
    /// After the game starts, the system will spawn the petal shield and the player can shoot bullets.
    /// The reticle will also be visible.
    /// </summary>
    public bool isReady
    {
        get => m_IsReady;
        set
        {
            m_IsReady = value;
        }
    }

    private bool m_IsControllerActive = false;

    public bool isControllerActive
    {
        get => m_IsControllerActive;
        set
        {
            m_IsControllerActive = value;
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

    private const float k_ShieldRechargeSpeed = 0.032f;

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

    private int m_DoctorStrangeCircleNum = 0;

    public int DoctorStrangeCircleNum
    {
        get => m_DoctorStrangeCircleNum;
    }

    public List<NetworkObject> BulletPrefabs = new List<NetworkObject>();

    public NetworkObject PortalPrefab;

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_ActivateWatchConnectivitySession();

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_SendMessageToAppleWatch(int messageIndex);

    /// <summary>
    /// This delegate function is called when a new message from Apple Watch is received.
    /// </summary>
    /// <param name="messageIndex">The type of the message from Apple Watch.</param>
    delegate void AppleWatchMessageReceived(int messageIndex);
    [AOT.MonoPInvokeCallback(typeof(AppleWatchMessageReceived))]
    static void OnAppleWatchMessageReceived(int messageIndex)
    {
        if ((AppleWatchMessageType)messageIndex == AppleWatchMessageType.StartGame)
        {
            Instance.isReady = true;
            return;
        }
        else
        {
            if (Instance.m_IsControllerActive)
            {
                switch ((AppleWatchMessageType)messageIndex)
                {
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
        }
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetAppleWatchMessageReceivedDelegate(AppleWatchMessageReceived callback);

    /// <summary>
    /// This delegate function is called when the circle number on the Apple Watch is updated.
    /// </summary>
    /// <param name="circleNum"></param>
    delegate void DoctorStrangeMessageReceived(int circleNum);
    [AOT.MonoPInvokeCallback(typeof(DoctorStrangeMessageReceived))]
    static void OnDoctorStrangeMessageReceived(int circleNum)
    {
        if (Instance.m_IsControllerActive)
        {
            Debug.Log($"[HadoController]: Doctor Strange circle number {circleNum}");
            Instance.m_DoctorStrangeCircleNum = circleNum;
            if (circleNum == 1)
            {
                Instance.nextControllerAction = HadoControllerAction.CastDoctorStrangeCircle;
            }
        }
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetDoctorStrangeMessageReceivedDelegate(DoctorStrangeMessageReceived callback);

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
        UnityHoloKit_SetDoctorStrangeMessageReceivedDelegate(OnDoctorStrangeMessageReceived);
    }

    private void Start()
    {
        //UnityHoloKit_ActivateWatchConnectivitySession();
        m_AudioSource = GetComponent<AudioSource>();
    }

    private void FixedUpdate()
    {
        if (!m_IsControllerActive) { return; }

        if (m_CurrentControllerState == HadoControllerState.Nothing)
        {
            if (m_CurrentAttackRecharge > m_CurrentAttackNum * k_AttackRechargeUnit)
            {
                m_CurrentAttackRecharge -= k_AttackRechargeSpeed;
                if (m_CurrentAttackRecharge < 0)
                {
                    m_CurrentAttackRecharge = 0f;
                }
            }

            if (m_CurrentShieldRecharge > m_CurrentShieldNum * k_ShieldRechargeUnit)
            {
                m_CurrentShieldRecharge -= k_ShieldRechargeSpeed;
                if (m_CurrentShieldRecharge < 0)
                {
                    m_CurrentShieldRecharge = 0f;
                }
            }

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
                //UnityHoloKit_SendMessageToAppleWatch((int)iPhoneMessageType.AttackRecharged);
                UnityHoloKit_SendMessageToAppleWatch(2);
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
                //UnityHoloKit_SendMessageToAppleWatch((int)iPhoneMessageType.ShieldRecharged);
                UnityHoloKit_SendMessageToAppleWatch(3);
                m_AudioSource.clip = m_ShieldRechargedAudioClip;
                m_AudioSource.Play();
                m_CurrentShieldNum++;
            }
            return;
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

    public void ReleaseAllEnergy()
    {
        m_CurrentAttackRecharge = 0f;
        m_CurrentAttackNum = 0;
        m_CurrentShieldRecharge = 0f;
        m_CurrentShieldNum = 0;
        m_CurrentControllerState = HadoControllerState.Nothing;
        m_NextControllerAction = HadoControllerAction.Nothing;
        m_DoctorStrangeCircleNum = 0;
    }
}
