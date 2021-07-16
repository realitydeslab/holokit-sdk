using System.Collections;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class HadoGrantShield : NetworkBehaviour
{
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitGrantShieldAudioClip;

    [SerializeField] private AudioClip m_CastShieldAudioClip;

    private int m_CurrentHealth;

    private int k_MaxHealth = 3;

    private float m_SpawnTime;

    private const float k_LifeTime = 6f;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_CastShieldAudioClip;
        m_AudioSource.Play();
        GetComponent<ForceShieldControl>().targetLerp = 1f;
        //GetComponent<MeshRenderer>().material.SetFloat("_Lerp", 1f);

        m_SpawnTime = Time.time;
        m_CurrentHealth = k_MaxHealth;
    }

    private void Update()
    {
        if (!IsOwner) { return; }
        if (Time.time - m_SpawnTime > k_LifeTime)
        {
            // Destroy the shield
            DestroyGrantShieldServerRpc();
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsOwner) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_CurrentHealth--;

            // Play hit sound effect
            m_AudioSource.clip = m_HitGrantShieldAudioClip;
            m_AudioSource.Play();
            var script = GetComponent<ForceShieldControl>();
            script.hitPosition = other.transform.position;
            script.hitAmp = 1;
            OnGrantShieldHitServerRpc(other.transform.position);
            
            if (m_CurrentHealth == 0)
            {
                // TODO: Play broken animation

                // TODO: Make the original model invisible

                script.targetLerp = 0f;
                DestroyGrantShieldServerRpc();
            }
        }
    }

    [ServerRpc]
    private void OnGrantShieldHitServerRpc(Vector3 hitPosition)
    {
        OnGrantShieldHitClientRpc(hitPosition);
    }

    [ClientRpc]
    private void OnGrantShieldHitClientRpc(Vector3 hitPosition)
    {
        if (IsOwner) { return; }

        // Play hit sound effect
        m_AudioSource.clip = m_HitGrantShieldAudioClip;
        m_AudioSource.Play();
        var script = GetComponent<ForceShieldControl>();
        script.hitPosition = hitPosition;
        script.hitAmp = 1;
    }

    [ServerRpc]
    private void DestroyGrantShieldServerRpc()
    {
        DestroyGrantShieldClientRpc();
        StartCoroutine(WaitForDestroy());
    }

    [ClientRpc]
    private void DestroyGrantShieldClientRpc()
    {
        var script = GetComponent<ForceShieldControl>();
        script.targetLerp = 0f;
    }

    IEnumerator WaitForDestroy()
    {
        yield return new WaitForSeconds(1.1f);
        Destroy(gameObject);
    }
}
