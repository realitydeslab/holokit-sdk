using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;

public class HandPan : NetworkBehaviour
{

    private Transform m_ARCamera;

    private HoloKitHandTracking m_HandTracker;

    private void Start()
    {
        if (IsOwner)
        {
            m_ARCamera = Camera.main.transform;
            m_HandTracker = FindObjectOfType<HoloKitHandTracking>();
        }
    }

    private void Update()
    {
        if (IsOwner)
        {
            transform.LookAt(m_ARCamera.position + 100f * m_ARCamera.forward);
            transform.position = m_HandTracker.CurrentHandPosition;
        }
    }
}
