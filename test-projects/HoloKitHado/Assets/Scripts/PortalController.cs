using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class PortalController : MonoBehaviour
{
    public int count = 0;
    public int countMax = 4;

    private bool m_IsDisappearing = false;

    [SerializeField]
    private float m_lerp;
    [SerializeField]
    private float m_speed =1f;

    public float Speed
    {
        set
        {
            m_speed = value;
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        m_lerp = 0.1f;
    }

    // Update is called once per frame
    void Update()
    {
        if(count > m_lerp)
        {
            if (count > countMax)
            {
                count = countMax;
            }
            m_lerp += Time.deltaTime * m_speed;
            if (m_lerp > count) m_lerp = count;
        }

        if(m_lerp == countMax)

        {
            MagicComplete();
        }

        if (count == 0)
        {
            if (m_IsDisappearing == false)
            {
                m_speed *= 4;
                m_IsDisappearing = true;
            }
            
            m_lerp -= Time.deltaTime * m_speed;
            if (m_lerp < 0)
            {
                m_lerp = 0;
            }
        }

        var lerp = m_lerp / countMax;
        GetComponent<VisualEffect>().SetFloat("Lerp", lerp);
    }

    void MagicComplete()
    {

    }
}
