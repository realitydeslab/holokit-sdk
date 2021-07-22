using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using MLAPI.Connection;

public class HadoPlayer : NetworkBehaviour
{
    
    [SerializeField] private NetworkObject m_BulletPrefab;

    [SerializeField] private NetworkObject m_PetalShieldPrefab;

    [SerializeField] private NetworkObject m_GrantShieldPrefab;

    [SerializeField] private NetworkObject m_DoctorStrangeCirclePrefab;

    [SerializeField] private NetworkObject m_BossPrefab;

    /// <summary>
    /// The offset from the center eye position to the spawn position of a new bullet.
    /// </summary>
    private Vector3 m_BulletSpawnOffset = new Vector3(0f, 0f, 0.6f);

    /// <summary>
    /// The offset from the center eye position to the spawn position of the grant shield.
    /// </summary>
    private Vector3 m_GrantShieldSpawnOffset = new Vector3(0, -1.2f, 1.3f);

    private Vector3 m_DoctorStrangeCircleSpawnOffset = new Vector3(0f, 0f, 1.7f);

    private NetworkVariableBool isReady = new NetworkVariableBool(new NetworkVariableSettings
    {
        WritePermission = NetworkVariablePermission.OwnerOnly,
        ReadPermission = NetworkVariablePermission.ServerOnly
    }, false);

    private bool m_IsRoundStarted = false;

    private bool m_IsStartRitualDone = false;

    private Transform m_ARCamera;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_GameStartAudioClip;

    [SerializeField] private AudioClip m_DefeatAudioClip;

    [SerializeField] private AudioClip m_VictoryAudioClip;

    private bool m_IsSpectator;

    // TODO: Adjust this value.
    private float m_BulletSpeed = 400f;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        
        if (IsOwner)
        {
            m_ARCamera = Camera.main.transform;
            HadoController.UnityHoloKit_ActivateWatchConnectivitySession();
            HadoController.UnityHoloKit_SendMessageToAppleWatch(0);

            if (SceneManager.GetActiveScene().name.Equals("HadoTestScene"))
            {
                m_IsSpectator = HadoUIManager.Instance.IsSpectator;
            }
            else if (SceneManager.GetActiveScene().name.Equals("PPvE"))
            {
                m_IsSpectator = PPvEUIManager.Instance.IsSpectator;
            }
        }
    }

    private void Update()
    {
        // Each device can only control the player instance of their own.
        if (!IsOwner) { return; }

        if (m_IsSpectator)
        {
            if (!isReady.Value)
            {
                isReady.Value = true;
            }
            return;
        }

        // Am I ready?
        if (!isReady.Value && HadoController.Instance.isReady)
        {
            isReady.Value = true;
        }

        if (!m_IsRoundStarted)
        {
            // On the server side, check if everyone is ready.
            if (IsServer)
            {
                foreach (NetworkClient networkClient in NetworkManager.Singleton.ConnectedClients.Values)
                {
                    if (networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
                    {
                        if (!script.isReady.Value)
                        {
                            return;
                        }
                    }
                }
                StartRoundServerRpc();
            }
            return;
        }

        if (!m_IsStartRitualDone)
        {
            Debug.Log("[HadoPlayer]: Round started!");
            m_AudioSource.clip = m_GameStartAudioClip;
            m_AudioSource.Play();
            SpawnPetalShieldServerRpc();
            HadoController.Instance.isControllerActive = true;

            m_IsStartRitualDone = true;
        }

        if (HadoController.Instance.nextControllerAction == HadoControllerAction.Fire)
        {
            // Fire
            if (HadoController.Instance.currentAttackNum > 0)
            {
                Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
                Vector3 bulletSpawnPosition = centerEyePosition + m_ARCamera.TransformVector(m_BulletSpawnOffset);
                FireServerRpc(bulletSpawnPosition, m_ARCamera.forward);
                HadoController.Instance.AfterAttack();
            }
            else
            {
                Debug.Log("[HadoPlayer]: bullet not charged");
            }
            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
        else if (HadoController.Instance.nextControllerAction == HadoControllerAction.CastShield)
        {
            // Cast shield
            if (HadoController.Instance.currentShieldNum > 0)
            {
                Debug.Log("[HadoPlayer]: cast shield");
                Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
                Vector3 shieldPosition = centerEyePosition + m_ARCamera.TransformVector(m_GrantShieldSpawnOffset);

                //Vector3 frontVector = Vector3.ProjectOnPlane(m_ARCamera.forward, new Vector3(0f, 1f, 0f)).normalized;
                Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;
                Quaternion shieldRotation = Quaternion.Euler(new Vector3(0f, cameraEuler.y, 0f));

                CastShieldServerRpc(shieldPosition, shieldRotation);
                HadoController.Instance.AfterCastShield();
            }
            else
            {
                Debug.Log("[HadoPlayer]: shield not charged");
            }
            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
        else if (HadoController.Instance.nextControllerAction == HadoControllerAction.CastDoctorStrangeCircle)
        {
            // Cast Doctor Strange circle
            Debug.Log("[HadoPlayer]: cast Doctor Strange circle");
            Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
            Vector3 circlePosition = centerEyePosition + m_ARCamera.TransformVector(m_DoctorStrangeCircleSpawnOffset);

            Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;
            Quaternion circleRotation = Quaternion.Euler(new Vector3(0f, cameraEuler.y, 0f));
            CastDoctorStrangeCircleServerRpc(circlePosition, circleRotation);

            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
    }

    [ServerRpc]
    private void SpawnPetalShieldServerRpc()
    {
        var petalShieldInstance = Instantiate(m_PetalShieldPrefab, Vector3.zero, Quaternion.identity);
        petalShieldInstance.SpawnWithOwnership(OwnerClientId);
    }

    [ServerRpc]
    private void FireServerRpc(Vector3 position, Vector3 direction)
    {
        var bulletInstance = Instantiate(m_BulletPrefab, position, Quaternion.identity);
        if(bulletInstance.TryGetComponent<HadoBullet>(out var bulletScript)) {
            bulletScript.InitialForce.Value = direction * m_BulletSpeed;
        }
        bulletInstance.Spawn();
    }

    [ServerRpc]
    private void CastShieldServerRpc(Vector3 position, Quaternion rotation)
    {
        var shieldInstance = Instantiate(m_GrantShieldPrefab, position, rotation);
        shieldInstance.SpawnWithOwnership(OwnerClientId);
    }

    [ServerRpc]
    private void CastDoctorStrangeCircleServerRpc(Vector3 position, Quaternion rotation)
    {
        var circleInstance = Instantiate(m_DoctorStrangeCirclePrefab, position, rotation);
        circleInstance.SpawnWithOwnership(OwnerClientId);
    }

    [ServerRpc]
    private void StartRoundServerRpc()
    {
        foreach (NetworkClient networkClient in NetworkManager.Singleton.ConnectedClients.Values)
        {
            if (networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
            {
                script.StartRoundClientRpc();
            }
        }
        HadoPetalShield.ShouldDestroyAllInstances.Value = false;
    }

    [ClientRpc]
    private void StartRoundClientRpc()
    {
        if (!IsOwner) { return; }

        m_IsRoundStarted = true;
    }

    [ServerRpc]
    public void RoundOverServerRpc(ulong loserId)
    {
        foreach (NetworkClient networkClient in NetworkManager.Singleton.ConnectedClients.Values)
        {
            if (networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
            {
                script.RoundOverClientRpc(loserId);
            }
        }
    }

    [ClientRpc]
    private void RoundOverClientRpc(ulong loserId)
    {
        if (!IsOwner) { return; }

        if (!m_IsSpectator)
        {
            isReady.Value = false;
        }
        m_IsRoundStarted = false;
        m_IsStartRitualDone = false;

        if (NetworkManager.Singleton.LocalClientId == loserId)
        {
            m_AudioSource.clip = m_DefeatAudioClip;
            m_AudioSource.Play();
        }
        else
        {
            m_AudioSource.clip = m_VictoryAudioClip;
            m_AudioSource.Play();
        }
        HadoController.Instance.isControllerActive = false;
        HadoController.Instance.isReady = false;
        HadoController.Instance.ReleaseAllEnergy();
    }

    [ServerRpc]
    public void SpawnBossServerRpc(Vector3 position, Quaternion rotation)
    {
        if (m_BossPrefab != null)
        {
            var bossInstance = Instantiate(m_BossPrefab, position, rotation);
            bossInstance.Spawn();
            isReady.Value = true;
        }
    }

    [ClientRpc]
    public void ReviveClientRpc()
    {
        if (IsOwner)
        {
            HadoController.Instance.isControllerActive = false;
            HadoController.Instance.ReleaseAllEnergy();
            StartCoroutine(WaitAndRevive(5f));
        }
    }

    IEnumerator WaitAndRevive(float time)
    {
        yield return new WaitForSeconds(time);
        m_IsStartRitualDone = false;
    }
}
