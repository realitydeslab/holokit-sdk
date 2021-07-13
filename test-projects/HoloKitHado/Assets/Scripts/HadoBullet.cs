using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class HadoBullet : NetworkBehaviour
{
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPetalShieldAudioClip;

    [SerializeField] private AudioClip m_HitGrantShieldAudioClip;

    [SerializeField] private NetworkObject m_BulletExplosionPrefab;

    private void OnTriggerEnter(Collider other)
    {
        // We handle collision only on the server side.
        if (!IsServer) { return; }

        if (other.tag.Equals("Petal Shield"))
        {
            m_AudioSource.clip = m_HitPetalShieldAudioClip;
            m_AudioSource.Play();
            PlayHitPetalShieldAudioServerRpc();
        }
        else if (other.tag.Equals("Grant Shield"))
        {
            m_AudioSource.clip = m_HitGrantShieldAudioClip;
            m_AudioSource.Play();
            PlayHitGrantShieldAudioServerRpc();
        }
        
        if (m_BulletExplosionPrefab != null)
        {
            // Spawn the explosion vfx through the network.
            var explosionInstance = Instantiate(m_BulletExplosionPrefab, this.transform.position, Quaternion.identity);
            explosionInstance.Spawn();
        }
    }

    [ServerRpc]
    private void PlayHitPetalShieldAudioServerRpc()
    {
        PlayHitPetalShieldAudioClientRpc();
    }

    [ClientRpc]
    private void PlayHitPetalShieldAudioClientRpc()
    {
        if (!IsServer)
        {
            m_AudioSource.clip = m_HitPetalShieldAudioClip;
            m_AudioSource.Play();
        }
    }

    [ServerRpc]
    private void PlayHitGrantShieldAudioServerRpc()
    {
        PlayHitGrantShieldAudioClientRpc();
    }

    [ClientRpc]
    private void PlayHitGrantShieldAudioClientRpc()
    {
        if (!IsServer)
        {
            m_AudioSource.clip = m_HitGrantShieldAudioClip;
            m_AudioSource.Play();
        }
    }
}
