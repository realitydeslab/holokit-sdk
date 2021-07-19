using UnityEngine;
using UnityEngine.VFX;
using MLAPI;

public class DoctorStrangeCircle : NetworkBehaviour
{
    private VisualEffect m_Vfx;

    private AudioSource m_AudioSource;

    [SerializeField] private AudioClip m_CircleAudioClip;

    private void Start()
    {
        if (IsOwner)
        {
            m_Vfx = GetComponent<VisualEffect>();
        }
        // TODO: Start to loop the audio effect
    }

    private void Update()
    {
        if (IsOwner)
        {

        }
    }
}
