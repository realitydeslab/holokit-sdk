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

    private const float k_LifeTime = 10f;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_CastShieldAudioClip;
        m_AudioSource.Play();
        GetComponent<ForceShieldControl>().targetLerp = 1f;

        if (IsServer)
        {
            m_SpawnTime = Time.time;
            m_CurrentHealth = k_MaxHealth;
        }
    }

    private void Update()
    {
        if (!IsServer) { return; }
        if (Time.time - m_SpawnTime > k_LifeTime)
        {
            // Destroy the shield
            DestroyGrantShield();
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsServer) { return; }

        if (other.tag.Equals("Bullet"))
        {
            m_CurrentHealth--;

            OnGrantShieldHitClientRpc(other.transform.position);
            
            if (m_CurrentHealth == 0)
            {
                DestroyGrantShield();
            }
        }
    }

    [ClientRpc]
    private void OnGrantShieldHitClientRpc(Vector3 hitPosition)
    {
        // Play hit sound effect
        m_AudioSource.clip = m_HitGrantShieldAudioClip;
        m_AudioSource.Play();
        var script = GetComponent<ForceShieldControl>();
        script.hitPosition = hitPosition;
        script.hitAmp = 1;
    }

    private void DestroyGrantShield()
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
        yield return new WaitForSeconds(1.05f);
        Destroy(gameObject);
    }
}
