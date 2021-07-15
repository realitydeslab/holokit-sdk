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
    private Vector3 m_GrantShieldSpawnOffset = new Vector3(0, -1f, 0.8f);

    /// <summary>
    /// Has this player's petal shield already been spawned?
    /// </summary>
    private bool m_IsPetalShieldSpawned = false;

    private Transform m_ARCamera;

    // TODO: Adjust this value.
    private float m_BulletSpeed = 80f;

    private void Start()
    {
        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        // Each device can only control the player instance of their own.
        if (!IsOwner) { return; }

        if (HadoController.Instance.isGameStarted && !m_IsPetalShieldSpawned)
        {
            Debug.Log("[HadoPlayer]: game started!");
            SpawnPetalShieldServerRpc();
            m_IsPetalShieldSpawned = true;
        }

        if (HadoController.Instance.nextControllerAction == HadoControllerAction.Fire)
        {
            // Fire
            Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
            Vector3 bulletSpawnPosition = centerEyePosition + m_ARCamera.TransformVector(m_BulletSpawnOffset);
            FireServerRpc(bulletSpawnPosition, m_ARCamera.forward);
            
            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
        else if (HadoController.Instance.nextControllerAction == HadoControllerAction.CastShield)
        {
            // TODO: Cast shield
            Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
            Vector3 shieldSpawnPosition = centerEyePosition + m_ARCamera.TransformVector(m_GrantShieldSpawnOffset);
            CastShieldServerRpc(shieldSpawnPosition, m_ARCamera.rotation);

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

    }

    private void OnPetalShieldBroken()
    {

    }
}
