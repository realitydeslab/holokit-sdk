using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.Transports.MultipeerConnectivity;

public class PhantomBuddhasPlayer : NetworkBehaviour
{
    [SerializeField] private List<NetworkObject> m_Models = new List<NetworkObject>();

    [SerializeField] private NetworkObject m_HandPrefab;

    private bool m_ThingsSpawned = false;

    private Transform m_ARCamera;

    private bool m_IsGameStarted = false;

    public bool IsGameStarted
    {
        get => m_IsGameStarted;
        set
        {
            m_IsGameStarted = value;
        }
    }

    private void Start()
    {
        if (!IsServer) return;

        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        if (!IsServer) return;

        if (!m_ThingsSpawned && HoloKitGameManager.Instance.IsGameStarted)
        {
            m_ThingsSpawned = true;

            // Notify clients that the game has started.
            GameStartedClientRpc();

            // Spawn models
            foreach (NetworkObject model in m_Models)
            {
                Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
                Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;

                var modelInstance = Instantiate(model);
                modelInstance.Spawn();
            }

            // Spawn the hand
            var handInstance = Instantiate(m_HandPrefab);
            handInstance.Spawn();
        }
    }

    [ClientRpc]
    private void GameStartedClientRpc()
    {
        if (!IsServer)
        {
            Handheld.Vibrate();
            HoloKitGameManager.Instance.StartAsClient();
            // BETA: Stop broswing as a client.
            MultipeerConnectivityTransport.UnityHoloKit_MultipeerStopBrowsing();
        }
    }

    [ServerRpc]
    private void SpawnTrackedHandServerRpc()
    {
        var handInstance = Instantiate(m_HandPrefab);
        handInstance.SpawnWithOwnership(OwnerClientId);
    }
}
