using System.Collections;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;

public class DoctorStrangeCircle : NetworkBehaviour
{

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_CircleAudioClip;

    private int m_CircleNum;

    private PortalController m_ControllerScript;

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

        if (other.tag.Equals("DragonBullet"))
        {
            // TODO: Teleport 
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
