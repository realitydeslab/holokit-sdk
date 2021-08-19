using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;

public class PhantomBuddhasPlayer : NetworkBehaviour
{
    [SerializeField] private List<NetworkObject> m_Models = new List<NetworkObject>();

    [SerializeField] private NetworkObject m_Hand;

    private bool m_ThingsSpawned = false;

    private Transform m_ARCamera;

    private void Start()
    {
        if (!IsServer) return;

        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        if (!IsServer) return;

        if (!m_ThingsSpawned && PhantomBuddhasGameManager.Instance.IsGameStarted)
        {
            m_ThingsSpawned = true;

            // Spawn models
            foreach(NetworkObject model in m_Models)
            {
                Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
                Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;

                var modelInstance = Instantiate(model, centerEyePosition, Quaternion.Euler(new Vector3(0f, cameraEuler.y, 0f)));
                modelInstance.Spawn();
            }

            // Spawn the hand
            
        }
    }
}
