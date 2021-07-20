using System.Collections;
using UnityEngine;
using MLAPI;

public class HadoBullet : NetworkBehaviour
{
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_FireAudioClip;

    private SphereCollider m_Collider;

    private int m_FrameCount = 0;

    private int k_FrameToOpenCollider = 5;

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_FireAudioClip;
        m_AudioSource.Play();
        m_Collider = GetComponent<SphereCollider>();
        m_Collider.enabled = false;
    }

    private void Update()
    {
        if (++m_FrameCount == k_FrameToOpenCollider)
        {
            m_Collider.enabled = true;
        }

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
            if (other.tag.Equals("Shield") || other.tag.Equals("Enemy"))
            {
                StartCoroutine(WaitForDestroy());
            }            
        }
    }

    IEnumerator WaitForDestroy()
    {
        yield return new WaitForSeconds(0.1f);
        Destroy(gameObject);
    }
}
