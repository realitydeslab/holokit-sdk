using System.Collections;
using UnityEngine;
using UnityEngine.VFX;
using MLAPI;
using MLAPI.Messaging;

public class HadoGrantShield : NetworkBehaviour
{
    private VisualEffect m_Vfx;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitGrantShieldAudioClip;

    private int m_CurrentHealth;

    private int k_MaxHealth = 3;

    private void Start()
    {
        m_Vfx = GetComponent<VisualEffect>();
        m_AudioSource = GetComponent<AudioSource>();
        m_CurrentHealth = k_MaxHealth;
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsOwner) { return; }

        if (other.tag.Equals("Bullet"))
        {
            // TODO: Trigger the hit animation

            // Play hit sound effect
            m_AudioSource.clip = m_HitGrantShieldAudioClip;
            m_AudioSource.Play();
            OnGrantShieldHitServerRpc();

            m_CurrentHealth--;
            if (m_CurrentHealth == 0)
            {
                // TODO: Play broken animation

                // TODO: Make the original model invisible

                OnGrantShieldBrokenServerRpc();
            }
        }
    }

    [ServerRpc]
    private void OnGrantShieldHitServerRpc()
    {
        OnGrantShieldHitClientRpc();
    }

    [ClientRpc]
    private void OnGrantShieldHitClientRpc()
    {
        if (IsOwner) { return; }
        // TODO: Trigger the hit animation

        // Play hit sound effect
        m_AudioSource.clip = m_HitGrantShieldAudioClip;
        m_AudioSource.Play();
    }

    [ServerRpc]
    private void OnGrantShieldBrokenServerRpc()
    {
        OnGrantShieldBrokenClientRpc();
    }

    [ClientRpc]
    private void OnGrantShieldBrokenClientRpc()
    {
        if (!IsOwner)
        {
            // TODO: Play broken down animation

            // TODO: Make the original model invisible

        }

        // Destroy this instance on the server side.
        if (IsServer)
        {
            StartCoroutine(WaitForDestroy());
        }
    }

    IEnumerator WaitForDestroy()
    {
        yield return new WaitForSeconds(3);
        Destroy(gameObject);
    }
}
