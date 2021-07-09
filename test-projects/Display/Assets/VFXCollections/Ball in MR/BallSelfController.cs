using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BallSelfController : MonoBehaviour
{
    [SerializeField] private float m_ballSize=1;
    [SerializeField] private float speed=1;

    public Vector3 hitPosition = Vector3.zero;
    public float Amp = 0;
    int n = 0; // count
    // Start is called before the first frame update
    void Start()
    {
        transform.localScale = Vector3.zero;
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        if (n == 0)
        {
            StartCoroutine(GiveBirthToBall());
            n = 1;
        }

        if(hitPosition != Vector3.zero)
        {
            transform.GetComponent<MeshRenderer>().material.SetVector("_Position", hitPosition);
            transform.GetComponent<MeshRenderer>().material.SetFloat("_Amp", Amp);
        }

        if (Amp > 0)
        {
            Amp -= Time.deltaTime;
        }
    }

    IEnumerator GiveBirthToBall()
    {
       while (transform.localScale.x < m_ballSize)
        {
            float add = Time.deltaTime * speed;
            transform.localScale += new Vector3(add, add, add);
            yield return new WaitForFixedUpdate();
        }
    }
}
