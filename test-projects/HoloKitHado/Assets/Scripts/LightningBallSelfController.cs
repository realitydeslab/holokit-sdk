using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightningBallSelfController : MonoBehaviour
{
    public Vector3 SpawnPosition = Vector3.zero;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        this.transform.position = SpawnPosition;
    }
}
