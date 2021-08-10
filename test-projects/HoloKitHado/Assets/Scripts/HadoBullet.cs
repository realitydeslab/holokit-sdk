using UnityEngine;
using MLAPI;
using MLAPI.NetworkVariable;

public class HadoBullet : NetworkBehaviour
{
    [SerializeField] private bool isForcedLookCamera = false;
    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_FireAudioClip;

    private SphereCollider m_Collider;

    private int m_FrameCount = 0;

    private int k_FrameToOpenCollider = 5;

    public NetworkVariableVector3 InitialForce = new NetworkVariableVector3(new NetworkVariableSettings
    {
        WritePermission = NetworkVariablePermission.OwnerOnly,
        ReadPermission = NetworkVariablePermission.Everyone
    }, Vector3.zero);

    private void Start()
    {
        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_FireAudioClip;
        m_AudioSource.Play();
        if (IsServer)
        {
            m_Collider = GetComponent<SphereCollider>();
            m_Collider.enabled = false;
        }

        GetComponent<Rigidbody>().AddForce(InitialForce.Value);
    }

    private void Update()
    {
        if (isForcedLookCamera)
        {
            this.transform.LookAt(Camera.main.transform.position);
        }

        if (IsServer)
        {
            if (++m_FrameCount == k_FrameToOpenCollider)
            {
                m_Collider.enabled = true;
            }

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
                Destroy(gameObject);
            }            
        }
    }
}
