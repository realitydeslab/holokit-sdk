using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ForceShieldControl : MonoBehaviour
{
    [Range(0, 1)]
    public float targetLerp;
    private float lerp;
    [SerializeField]
    private float m_BirthSpeed = .1f;

    // for hitting
    public Vector3 hitPosition = Vector3.zero;
    [Range(0,1)]
    public float hitAmp = 0;
    bool m_isInReaction = false;
    private float m_speed = 1f;

    // Start is called before the first frame update
    void Start()
    {
        targetLerp = 1;
    }

    // Update is called once per frame
    void Update()
    {
        ShieldAnimationControl();
        ShieldHittingControl();
    }

    void ShieldAnimationControl()
    {
        lerp = GetComponent<MeshRenderer>().material.GetFloat("_Lerp");

        float t = targetLerp - lerp;
        if (t > 0)
        {
            lerp += m_BirthSpeed * Time.deltaTime;
            if (lerp > 1) lerp = 1;
        }
        else if (t < 0)
        {
            lerp -= m_BirthSpeed * Time.deltaTime;
            if (lerp < 0) lerp = 0;
        }
        else
        {
        }
        GetComponent<MeshRenderer>().material.SetFloat("_Lerp", lerp);
    }

    void ShieldHittingControl()
    {
        if (hitAmp == 1)
        {
            m_isInReaction = true;
            GetComponent<MeshRenderer>().material.SetVector("Hit_Position", hitPosition);

        }

        if (m_isInReaction)
        {
            hitAmp -= Time.deltaTime * m_speed;
            GetComponent<MeshRenderer>().material.SetFloat("Hit_Amp", hitAmp);
            if (hitAmp < 0)
            {
                hitAmp = 0;
                m_isInReaction = false;
            }
        }
    }
}