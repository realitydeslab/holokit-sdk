using UnityEngine;
using UnityEngine.XR.ARFoundation;
using MLAPI;

public class BallsPlayer : NetworkBehaviour
{
    [SerializeField] private NetworkObject m_BallPrefab;

    [SerializeField] private NetworkObject m_HandPrefab;

    [SerializeField] private GameObject m_SpawnBallButton;

    private bool m_IsPlaneActive = false;

    private void Start()
    {
        if (IsServer)
        {
            // Spawn the button
            Instantiate(m_SpawnBallButton);
        }

        var handInstance = Instantiate(m_HandPrefab);
        handInstance.SpawnWithOwnership(OwnerClientId);
    }

    private void Update()
    {
        if (IsServer)
        {
            // Activate the AR plane manager after the game started.
            // This is only active on the server side.
            if (HoloKitGameManager.Instance.IsGameStarted && !m_IsPlaneActive)
            {
                m_IsPlaneActive = true;
                FindObjectOfType<ARPlaneManager>().enabled = true;
            }
        }
    }
}
