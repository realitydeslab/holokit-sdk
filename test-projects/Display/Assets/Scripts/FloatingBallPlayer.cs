using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using System.Runtime.InteropServices;
using System;
using MLAPI.Transports.MultipeerConnectivity;

public class FloatingBallPlayer : NetworkBehaviour
{

    [SerializeField] private NetworkObject m_FloatingBallPrefab;

    [SerializeField] private NetworkObject m_HandSpherePrefab;

    [SerializeField] private Vector3 m_SpawningOffset = new Vector3(0f, 0.2f, 1f);

    public static Vector3 CameraToCenterEyeOffset;

    [DllImport("__Internal")]
    public static extern int UnityHoloKit_GetRenderingMode();

    public override void NetworkStart()
    {
        if (IsOwner)
        {
            //SpawnHandSphereServerRpc();
        }
    }

    private void Start()
    {
        //if (IsOwner)
        //{
        //    Debug.Log($"[FloatingBallPlayer]: Owner {OwnerClientId} started.");
        //    SpawnHandSphereServerRpc();
        //}
    }

    private void Update()
    {
    
    }

    public void SpawnFloatingBall()
    {
        if (!IsServer) return;
        Camera arCamera = Camera.main;
        Vector3 spawningPosition = arCamera.transform.position + arCamera.transform.TransformVector(m_SpawningOffset);
        if (UnityHoloKit_GetRenderingMode() == 2) {
            //spawningPosition += arCamera.transform.TransformVector(CameraToCenterEyeOffset);
        }
        var floatingBall = Instantiate(m_FloatingBallPrefab, spawningPosition, new Quaternion(0f, 0f, 0f, 1f));
        floatingBall.Spawn();
    }

    [ServerRpc]
    private void SpawnHandSphereServerRpc()
    {
        var handSphereInstance = Instantiate(m_HandSpherePrefab, Vector3.zero, Quaternion.identity);
        handSphereInstance.SpawnWithOwnership(OwnerClientId);
        Debug.Log($"[FloatingBallPlayer]: spawn a network new hand sphere with ownership {OwnerClientId}");
    }

    public void SpawnHandSphere()
    {
        Debug.Log($"[FloatingBallPlayer]: client {OwnerClientId} spawned the hand sphere.");
        SpawnHandSphereServerRpc();
    }
}
