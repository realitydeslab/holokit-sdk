using System.Collections;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class HadoGrantShield : NetworkBehaviour
{
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitGrantShieldAudioClip;

    private int m_CurrentHealth;

    private int k_MaxHealth = 3;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_CurrentHealth = k_MaxHealth;
        GetComponent<ShieldAnimation>().targetLerp = 1f;
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsOwner) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_CurrentHealth--;
            // Trigger the hit animation
            HitAnimation();
            // Play hit sound effect
            m_AudioSource.clip = m_HitGrantShieldAudioClip;
            m_AudioSource.Play();
            OnGrantShieldHitServerRpc();
            
            if (m_CurrentHealth == 0)
            {
                // TODO: Play broken animation

                // TODO: Make the original model invisible

                OnGrantShieldBrokenServerRpc();
            }
        }
    }
    private void HitAnimation()
    {
        float targetLerp = 1f;
        switch(m_CurrentHealth)
        {
            case 2:
                targetLerp = 0.6f;
                break;
            case 1:
                targetLerp = 0.3f;
                break;
            case 0:
                targetLerp = 0f;
                break;
        }
        GetComponent<ShieldAnimation>().targetLerp = targetLerp;
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
        // Trigger the hit animation
        HitAnimation();
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
