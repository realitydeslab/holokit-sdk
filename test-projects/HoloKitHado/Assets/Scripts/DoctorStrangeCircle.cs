using System.Collections;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.Connection;

public class DoctorStrangeCircle : NetworkBehaviour
{

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_CircleAudioClip;

    private int m_CircleNum;

    private PortalController m_ControllerScript;

    public bool isSecondPortal = false;

    public Vector3 correspondingPortalPosition;

    public Quaternion correspondingPortalRotation;

    public Vector3 correspondingPortalDirection;

    private void Start()
    {
        m_ControllerScript = GetComponent<PortalController>();

        m_AudioSource = GetComponent<AudioSource>();
        m_AudioSource.clip = m_CircleAudioClip;
        m_AudioSource.loop = true;
        m_AudioSource.Play();

        if (IsOwner)
        {
            m_CircleNum = 0;
        }

        if (IsServer && !isSecondPortal)
        {
            if (Random.value < 0.5)
            {
                // Left
                correspondingPortalPosition = transform.position + transform.forward * 2f - transform.right * 2f;
                correspondingPortalRotation = transform.rotation * Quaternion.AngleAxis(45f, Vector3.up);
                correspondingPortalDirection = (Quaternion.AngleAxis(45f, Vector3.up) * transform.forward).normalized;
            }
            else
            {
                // Right
                correspondingPortalPosition = transform.position + transform.forward * 2f + transform.right * 2f;
                correspondingPortalRotation = transform.rotation * Quaternion.AngleAxis(-45f, Vector3.up);
                correspondingPortalDirection = (Quaternion.AngleAxis(-45f, Vector3.up) * transform.forward).normalized;
            }
            var secondCircleInstance = Instantiate(HadoController.Instance.PortalPrefab, correspondingPortalPosition, correspondingPortalRotation);
            if (secondCircleInstance.TryGetComponent<DoctorStrangeCircle>(out var script))
            {
                script.isSecondPortal = true;
                script.correspondingPortalPosition = transform.position;
                script.correspondingPortalRotation = transform.rotation;
                script.correspondingPortalDirection = transform.forward;
            }
            secondCircleInstance.SpawnWithOwnership(OwnerClientId);
        }
    }

    private void Update()
    {
        if (IsOwner)
        {
            if (m_CircleNum != HadoController.Instance.DoctorStrangeCircleNum)
            {
                m_CircleNum = HadoController.Instance.DoctorStrangeCircleNum;
                CircleNumUpdateServerRpc(m_CircleNum);
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!IsServer) { return; }

        if (other.tag.Equals("Bullet"))
        {
            // Teleport the attack.
            if(other.transform.TryGetComponent<HadoBullet>(out var script))
            {
                if (!script.hasTransformed)
                {
                    script.hasTransformed = true;
                    script.ChangePositionServerRpc(correspondingPortalPosition, correspondingPortalRotation, correspondingPortalDirection);
                } 
            }
        }
    }

    [ServerRpc]
    private void CircleNumUpdateServerRpc(int circleNum)
    {
        if (circleNum == 0)
        {
            StartCoroutine(WaitAndDestroy(1.8f));
        }
        CircleNumUpdateClientRpc(circleNum);
    }

    [ClientRpc]
    private void CircleNumUpdateClientRpc(int circleNum)
    {
        m_ControllerScript.count = circleNum;
    }

    IEnumerator WaitAndDestroy(float time)
    {
        yield return new WaitForSeconds(time);
        Destroy(gameObject);
    }
}
