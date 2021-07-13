using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Messaging;

public class HadoPetalShield : NetworkBehaviour
{
    private Transform m_ARCamera;

    /// <summary>
    /// The offset from the center eye position to the petal shield.
    /// </summary>
    private Vector3 m_PetalShieldOffset = new Vector3(0, -0.2f, -0.5f);

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

        m_ARCamera = Camera.main.transform;
    }

    private void Update()
    {
        if (!IsOwner) { return; }

        // Update the petal shield's position and rotation according to the player's movement.
        Vector3 centerEyePosition = m_ARCamera.position + m_ARCamera.TransformVector(HoloKitSettings.CameraToCenterEyeOffset);
        Vector3 lookAtPosition = centerEyePosition + m_ARCamera.forward * 100f;
        transform.LookAt(lookAtPosition);
        transform.position = centerEyePosition + m_ARCamera.TransformVector(m_PetalShieldOffset);
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
