using UnityEngine;
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
    private Vector3 m_BulletSpawnOffset = new Vector3(0.3f, 0f, 0f);

    /// <summary>
    /// The offset from the center eye position to the spawn position of the grant shield.
    /// </summary>
    private Vector3 m_GrantShieldOffset = new Vector3(0, -1f, 0.7f);

    /// <summary>
    /// Has this player's petal shield already been spawned?
    /// </summary>
    private bool m_IsPetalShieldSpawned = false;

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
            // TODO: Fire

            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
        else if (HadoController.Instance.nextControllerAction == HadoControllerAction.CastShield)
        {
            // TODO: Cast shield

            HadoController.Instance.nextControllerAction = HadoControllerAction.Nothing;
        }
    }

    [ServerRpc]
    private void SpawnPetalShieldServerRpc()
    {
        var petalShieldInstance = Instantiate(m_PetalShieldPrefab, Vector3.zero, Quaternion.identity);
        petalShieldInstance.SpawnWithOwnership(OwnerClientId);
    }

    private void Fire()
    {

    }

    private void CastShield()
    {

    }

    private void OnPetalShieldBroken()
    {

    }
}
