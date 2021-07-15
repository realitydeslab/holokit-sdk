using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;

public class HadoPlayer : NetworkBehaviour
{
    
    [SerializeField] private NetworkObject m_BulletPrefab;

    [SerializeField] private NetworkObject m_PetalShieldPrefab;

    [SerializeField] private NetworkObject m_GrantShieldPrefab;

    [SerializeField] private GameObject m_DefeatPrefab;

    /// <summary>
    /// The offset from the center eye position to the spawn position of a new bullet.
    /// </summary>
    private Vector3 m_BulletSpawnOffset = new Vector3(0f, 0f, 0.6f);

    /// <summary>
    /// The offset from the center eye position to the spawn position of the grant shield.
    /// </summary>
    private Vector3 m_GrantShieldSpawnOffset = new Vector3(0, -0.6f, 0.8f);

    /// <summary>
    /// Has this player's petal shield already been spawned?
    /// </summary>
    private bool m_IsPetalShieldSpawned = false;

    private Transform m_ARCamera;

    // TODO: Adjust this value.
    private float m_BulletSpeed = 80f;

    private bool m_IsAlive = true;

    private void Start()
    {
        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        // Each device can only control the player instance of their own.
        if (!IsOwner) { return; }

        if (!m_IsPetalShieldSpawned && HadoController.Instance.isGameStarted)
        {
            Debug.Log("[HadoPlayer]: game started!");
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
                Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
                Vector3 shieldSpawnPosition = centerEyePosition + m_ARCamera.TransformVector(m_GrantShieldSpawnOffset);
                CastShieldServerRpc(shieldSpawnPosition, m_ARCamera.rotation);
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
        bulletInstance.SpawnWithOwnership(OwnerClientId);

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
        // TODO: Give a visual notification to the player.

    }
}
