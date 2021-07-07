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
    public static extern IntPtr UnityHoloKit_GetCameraToCenterEyeOffsetPtr();

    [DllImport("__Internal")]
    public static extern int UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(IntPtr ptr);

    [DllImport("__Internal")]
    public static extern int UnityHoloKit_GetRenderingMode();

    private void OnEnable()
    {
        // https://stackoverflow.com/questions/17634480/return-c-array-to-c-sharp/18041888
        IntPtr offsetPtr = UnityHoloKit_GetCameraToCenterEyeOffsetPtr();
        float[] offset = new float[3];
        Marshal.Copy(offsetPtr, offset, 0, 3);
        Debug.Log($"[FloatingBallPlayer]: camera to center eye offset [{offset[0]}, {offset[1]}, {offset[2]}]");
        CameraToCenterEyeOffset = new Vector3(offset[0], offset[1], offset[2]);

        UnityHoloKit_ReleaseCameraToCenterEyeOffsetPtr(offsetPtr);
    }

    public override void NetworkStart()
    {
        SpawnHandSphereServerRpc();
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
            spawningPosition += arCamera.transform.TransformVector(CameraToCenterEyeOffset);
        }
        var floatingBall = Instantiate(m_FloatingBallPrefab, spawningPosition, new Quaternion(0f, 0f, 0f, 1f));
        floatingBall.Spawn();
    }

    [ServerRpc]
    private void SpawnHandSphereServerRpc()
    {
        Debug.Log("SpawnHandSphereServerRpc");
        var handSphereInstance = Instantiate(m_HandSpherePrefab, Vector3.zero, Quaternion.identity);
        handSphereInstance.SpawnWithOwnership(OwnerClientId);
    }
}
