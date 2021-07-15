using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShieldAnimation : MonoBehaviour
{
    public float targetLerp;
    private float lerp;
    [SerializeField]
    private float m_Speed = 1f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        lerp = GetComponent<MeshRenderer>().material.GetFloat("_Lerp");

        float t = targetLerp - lerp;
        if (t > 0)
        {
            lerp += m_Speed * Time.deltaTime;
            if (lerp > 1) lerp = 1;
        }
        else{
            lerp -= m_Speed * Time.deltaTime;
            if (lerp < 0) lerp = 0;
        }
    }
}
