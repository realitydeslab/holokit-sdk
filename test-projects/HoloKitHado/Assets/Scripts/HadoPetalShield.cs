using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;

public class HadoPetalShield : NetworkBehaviour
{
    private Transform m_ARCamera;

    private float m_PetalShieldYOffset = -0.2f;

    private float m_PetalShieldZOffset = 0.4f;

    private int m_CurrentHealth;

    /// <summary>
    /// The current remaining health of the petal shield.
    /// </summary>
    public int currentHealth
    {
        get => m_CurrentHealth;
    }

    private int k_MaxHeath = 4;

    private float m_LastHitTime = 0f;

    private const float k_RecoveryTime = 3f;

    private void Start()
    {
        if (!IsOwner) { return; }
        Debug.Log("[HadoPetalShield]: petal shield spawned");
        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        if (!IsOwner) { return; }

        // Update the petal shield's position and rotation according to the player's movement.
        Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
        Vector3 frontVector = Vector3.ProjectOnPlane(m_ARCamera.forward, new Vector3(0f, 1f, 0f)).normalized;
        transform.position = centerEyePosition + frontVector * m_PetalShieldZOffset + new Vector3(0f, m_PetalShieldYOffset, 0f);

        Vector3 cameraEuler = m_ARCamera.rotation.eulerAngles;
        transform.rotation = Quaternion.Euler(new Vector3(0f, cameraEuler.y, 0f));
    }

    private void OnTriggerEnter(Collider other)
    {
        // We handle collisions only on the server side.
        if (!IsServer) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_LastHitTime = Time.time;
            OnPetalShieldHitServerRpc();

            m_CurrentHealth--;
            if (m_CurrentHealth < 0)
            {
                m_CurrentHealth = 0;
                OnPetalShieldBrokenServerRpc();
            }
        }
    }

    private void FixedUpdate()
    {
        if (!IsServer) { return; }

        if (Time.time - m_LastHitTime > k_RecoveryTime)
        {
            if (m_CurrentHealth != k_MaxHeath)
            {
                m_CurrentHealth++;
                OnPetalShieldRecoveredServerRpc();
            }
        }
    }
   
    [ServerRpc]
    private void OnPetalShieldHitServerRpc()
    {
        OnPetalShieldHitClientRpc();
    }

    [ClientRpc]
    private void OnPetalShieldHitClientRpc()
    {

    }

    [ServerRpc]
    private void OnPetalShieldRecoveredServerRpc()
    {
        OnPetalShieldRecoveredClientRpc();
    }

    [ClientRpc]
    private void OnPetalShieldRecoveredClientRpc()
    {

    }

    [ServerRpc]
    private void OnPetalShieldBrokenServerRpc()
    {
        OnPetalShieldBrokenClientRpc();
    }

    [ClientRpc]
    private void OnPetalShieldBrokenClientRpc()
    {

    }
}
