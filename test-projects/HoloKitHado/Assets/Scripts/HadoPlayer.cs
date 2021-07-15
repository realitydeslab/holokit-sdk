using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;

public class HadoPlayer : NetworkBehaviour
{
    
    [SerializeField] private NetworkObject m_BulletPrefab;

    [SerializeField] private NetworkObject m_PetalShieldPrefab;

    [SerializeField] private NetworkObject m_GrantShieldPrefab;

    /// <summary>
    /// The offset from the center eye position to the spawn position of a new bullet.
    /// </summary>
    private Vector3 m_BulletSpawnOffset = new Vector3(0f, 0f, 0.6f);

    /// <summary>
    /// The offset from the center eye position to the spawn position of the grant shield.
    /// </summary>
    private Vector3 m_GrantShieldSpawnOffset = new Vector3(0, -1.4f, 1.2f);

    /// <summary>
    /// Has this player's petal shield already been spawned?
    /// </summary>
    private bool m_IsPetalShieldSpawned = false;

    private Transform m_ARCamera;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_GameStartAudioClip;

    [SerializeField] private AudioClip m_DefeatAudioClip;

    [SerializeField] private AudioClip m_VictoryAudioClip;

    // TODO: Adjust this value.
    private float m_BulletSpeed = 80f;

    private bool m_IsAlive = true;

    private void Start()
    {
        m_ARCamera = Camera.main.transform;
        m_AudioSource = GetComponent<AudioSource>();
    }

    private void Update()
    {
        // Each device can only control the player instance of their own.
        if (!IsOwner) { return; }

        if (!m_IsPetalShieldSpawned && HadoController.Instance.isGameStarted)
        {
            Debug.Log("[HadoPlayer]: game started!");
            m_AudioSource.clip = m_GameStartAudioClip;
            m_AudioSource.Play();
            SpawnPetalShieldServerRpc();
            m_IsPetalShieldSpawned = true;
        }

        // The player can do nothing when died.
        if (!m_IsAlive) { return; }

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

                Vector3 frontVector = Vector3.ProjectOnPlane(m_ARCamera.forward, new Vector3(0f, 1f, 0f)).normalized;
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
        // Only the owner of the NetworkObject can add force to it.
        bulletInstance.Spawn();

        bulletInstance.GetComponent<Rigidbody>().AddForce(direction * m_BulletSpeed);
    }

    [ServerRpc]
    private void CastShieldServerRpc(Vector3 position, Quaternion rotation)
    {
        var shieldInstance = Instantiate(m_GrantShieldPrefab, position, rotation);
        shieldInstance.SpawnWithOwnership(OwnerClientId);
    }

    public void OnPetalShieldBroken()
    {
        Debug.Log("[HadoPlayer]: my petal shield has been broken.");
        m_IsAlive = false;
        // TODO: Give a notification to the player.
        m_AudioSource.clip = m_DefeatAudioClip;
        m_AudioSource.Play();
        // Notify the other player
        OnVictoryServerRpc();
    }

    [ServerRpc]
    private void OnVictoryServerRpc()
    {
        OnVictoryClientRpc();
    }

    [ClientRpc]
    private void OnVictoryClientRpc()
    {
        if(!IsOwner)
        {
            m_AudioSource.clip = m_VictoryAudioClip;
            m_AudioSource.Play();
        }
    }
}
