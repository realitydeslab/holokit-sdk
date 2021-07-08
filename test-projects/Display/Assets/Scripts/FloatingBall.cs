using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class FloatingBall : NetworkBehaviour
{

    [SerializeField] private float m_HandBouncingFactor = 0.2f;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_HitPlaneAudioClip;

    [SerializeField] private AudioClip m_HitHandAudioClip;
    
    void Start()
    {
        // (0.00, -9.81, 0.00) as default
        Physics.gravity = new Vector3(0f, -2f, 0f);

        m_AudioSource = GetComponent<AudioSource>();
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
                Vector3 direction = collision.transform.forward;
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

}
