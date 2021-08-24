using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class Ball : NetworkBehaviour
{
    private float m_HandBouncingFactor = 3f;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPlaneAudioClip;

    [SerializeField] private AudioClip m_HitHandAudioClip;

    private void Start()
    {
        // (0.00, -9.81, 0.00) as default
        Physics.gravity = new Vector3(0f, -2f, 0f);

        m_AudioSource = GetComponent<AudioSource>();
    }

    private void Update()
    {
        if (IsOwner && IsServer && transform.position.y < -3f)
        {
            Destroy(gameObject);
        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.tag.Equals("TrackedHand"))
        {
            if (IsServer)
            {
                Vector3 inDirection = GetComponent<Rigidbody>().velocity.normalized;
                Vector3 normal = collision.transform.forward.normalized;

                Vector3 newDirection = Vector3.Reflect(inDirection, normal);
                GetComponent<Rigidbody>().AddForce(newDirection * m_HandBouncingFactor);

                PlayHitHandAudioClipClientRpc();
                return;
            }
        }

        if (collision.gameObject.tag.Equals("Plane"))
        {
            if (IsServer)
            {
                PlayHitPlaneAudioClipClientRpc();
                return;
            }
        }
    }

    [ClientRpc]
    private void PlayHitHandAudioClipClientRpc()
    {
        m_AudioSource.clip = m_HitHandAudioClip;
        m_AudioSource.Play();
    }

    [ClientRpc]
    private void PlayHitPlaneAudioClipClientRpc()
    {
        m_AudioSource.clip = m_HitPlaneAudioClip;
        m_AudioSource.Play();
    }
}
