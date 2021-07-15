using System.Collections;
using UnityEngine;
using UnityEngine.XR.HoloKit;
using UnityEngine.VFX;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.Connection;

public class HadoPetalShield : NetworkBehaviour
{
    private Transform m_ARCamera;

    private VisualEffect m_Vfx;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPetalShieldAudioClip;

    private float m_PetalShieldYOffset = -0.2f;

    private float m_PetalShieldZOffset = 0.4f;

    private int m_CurrentHealth;

    private int k_MaxHeath = 4;

    private float m_LastHitTime = 0f;

    private const float k_RecoveryTime = 3f;

    /// <summary>
    /// If the petal shield is still alive?
    /// </summary>
    private bool m_IsPresent = true;

    private void Start()
    {
        if (!IsOwner) { return; }
        Debug.Log("[HadoPetalShield]: petal shield spawned");
        m_ARCamera = Camera.main.transform;
        m_Vfx = GetComponent<VisualEffect>();
        m_CurrentHealth = k_MaxHeath;
        m_AudioSource = GetComponent<AudioSource>();
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

        // Shield's health recovers if not gets hit.
        if (m_IsPresent && Time.time - m_LastHitTime > k_RecoveryTime)
        {
            if (m_CurrentHealth != k_MaxHeath)
            {
                m_CurrentHealth++;
                // TODO: Modify the VFX parameter

                OnPetalShieldRecoveredServerRpc();
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        // Each petal shield is handled by its owner.
        if (!IsOwner) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_LastHitTime = Time.time;
            // Modify the VFX parameter
            transform.GetChild(0).GetComponent<PetalSelfControl>().OnExplode();

            m_AudioSource.clip = m_HitPetalShieldAudioClip;
            m_AudioSource.Play();
            OnPetalShieldHitServerRpc();

            m_CurrentHealth--;
            if (m_CurrentHealth == 0)
            {
                m_IsPresent = false;
                // TODO: Play the shield broken animation
                
                OnPetalShieldBrokenServerRpc();

                // Notify the player object that the petal shiled has been broken
                var playerScript = GetLocalPlayerScript();
                if (playerScript != null)
                {
                    playerScript.OnPetalShieldBroken();
                }
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
        if (IsOwner) { return; }
        // Modify the VFX parameter
        transform.GetChild(0).GetComponent<PetalSelfControl>().OnExplode();
    }

    [ServerRpc]
    private void OnPetalShieldRecoveredServerRpc()
    {
        OnPetalShieldRecoveredClientRpc();
    }

    [ClientRpc]
    private void OnPetalShieldRecoveredClientRpc()
    {
        if (IsOwner) { return; }
        // TODO: Modify the VFX parameter

    }

    [ServerRpc]
    private void OnPetalShieldBrokenServerRpc()
    {
        OnPetalShieldBrokenClientRpc();
    }

    [ClientRpc]
    private void OnPetalShieldBrokenClientRpc()
    {
        if (!IsOwner)
        {
            // TODO: play shield broken animation

        }

        if (IsServer)
        {
            WaitForDestroy();
        }
    }

    IEnumerator WaitForDestroy()
    {
        yield return new WaitForSeconds(3);
        Destroy(gameObject);
    }

    private HadoPlayer GetLocalPlayerScript()
    {
        ulong localClientId = NetworkManager.Singleton.LocalClientId;
        if (!NetworkManager.Singleton.ConnectedClients.TryGetValue(localClientId, out NetworkClient networkClient))
        {
            return null;
        }

        if (!networkClient.PlayerObject.TryGetComponent<HadoPlayer>(out HadoPlayer script))
        {
            return null;
        }
        return script;
    }
}
