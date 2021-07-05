using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestingBall : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        GetComponent<Rigidbody>().AddForce(new Vector3(20f, 0f, 0f));
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
