using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class PortalController : MonoBehaviour
{

    public int count = 0;
    public int countMax = 4;

    [SerializeField]
    private float m_lerp;
    [SerializeField]
    private float m_speed =1f;
    // Start is called before the first frame update
    void Start()
    {
        m_lerp = 0;
    }

    // Update is called once per frame
    void Update()
    {
        if(count > m_lerp)
        {
            m_lerp += Time.deltaTime * m_speed;
            if (m_lerp > count) m_lerp = count;
        }

        if(m_lerp == countMax)
        {
            MagicComplete();
        }

        var lerp = m_lerp / countMax;
        GetComponent<VisualEffect>().SetFloat("Lerp", lerp);
    }

    void MagicComplete()
    {

    }
}
