using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class FloatingBall : NetworkBehaviour
{

    private float m_HandBouncingFactor = 1.5f;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPlaneAudioClip;

    [SerializeField] private AudioClip m_HitHandAudioClip;

    private void OnEnable()
    {
        if (IsOwner)
        {
            NetworkManager.Singleton.OnClientConnectedCallback += OnClientConnected;
        }
    }

    private void OnDisable()
    {
        if (IsOwner)
        {
            NetworkManager.Singleton.OnClientConnectedCallback -= OnClientConnected;
        }
    }

    void Start()
    {
        // (0.00, -9.81, 0.00) as default
        Physics.gravity = new Vector3(0f, -2f, 0f);

        m_AudioSource = GetComponent<AudioSource>();
    }

    private void Update()
    {
        // If the ball falling off the ground, we destroy it
        if (!IsOwner) { return; }
        if (transform.position.y < -3f)
        {
            DestroyBallServerRpc();
        }
    }

    private void OnCollisionEnter(Collision collision)
    {   
        if (collision.gameObject.tag.Equals("Meshing"))
        {
            //Debug.Log("Hit meshing");
            HittingRippleRoom.Instance.SetHitPoint(collision.contacts[0].point);
            return;
        }
        if (collision.gameObject.tag.Equals("HandSphere"))
        {
            //Debug.Log("Collided with hand sphere.");
            if (IsServer)
            {
                Vector3 inDirection = GetComponent<Rigidbody>().velocity.normalized;
                Vector3 normal = collision.transform.forward.normalized;
                Vector3 direction = Vector3.Reflect(inDirection, normal);
                GetComponent<Rigidbody>().AddForce(direction * m_HandBouncingFactor);

                // Play audio effect
                m_AudioSource.clip = m_HitHandAudioClip;
                m_AudioSource.Play();
                PlayAudioEffectHitHandServerRpc();
                return;
            }
        }
        if (collision.gameObject.tag.Equals("Plane"))
        {
            // Play audio effect
            if (IsServer)
            {
                m_AudioSource.clip = m_HitPlaneAudioClip;
                m_AudioSource.Play();
                PlayAudioEffectHitPlaneServerRpc();
                return;
            }
        }
    }

    [ServerRpc]
    private void PlayAudioEffectHitPlaneServerRpc()
    {
        PlayAudioEffectHitPlaneClientRpc();
    }

    [ClientRpc]
    private void PlayAudioEffectHitPlaneClientRpc()
    {
        if (!IsServer)
        {
            m_AudioSource.clip = m_HitPlaneAudioClip;
            m_AudioSource.Play();
        }
    }

    [ServerRpc]
    private void PlayAudioEffectHitHandServerRpc()
    {
        PlayAudioEffectHitHandClientRpc();
    }

    [ClientRpc]
    private void PlayAudioEffectHitHandClientRpc()
    {
        if (!IsServer)
        {
            m_AudioSource.clip = m_HitHandAudioClip;
            m_AudioSource.Play();
        }
    }

    [ServerRpc]
    private void DestroyBallServerRpc()
    {
        Debug.Log("[FloatingBall]: a ball is destroyed on the server side.");
        Destroy(gameObject);
    }

    private void OnClientConnected(ulong clientId)
    {
        Destroy(gameObject);
    }
}
