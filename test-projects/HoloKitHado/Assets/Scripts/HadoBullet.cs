using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class HadoBullet : NetworkBehaviour
{
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_FireAudioClip;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_FireAudioClip;
        m_AudioSource.Play();
    }

    private void Update()
    {
        if (IsServer)
        {
            if (Vector3.Distance(transform.position, Vector3.zero) > 30f)
            {
                // Detroy the bullet which is too far away from the battle field.
                Destroy(gameObject);
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (IsServer)
        {
            if (other.tag.Equals("Shield"))
            {
                Destroy(gameObject);
            }            
        }
    }
}
