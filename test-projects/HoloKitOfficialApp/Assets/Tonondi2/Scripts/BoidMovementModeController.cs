using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BoidMovementModeController : MonoBehaviour
{

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void ChangeMovementMode()
    {
        Debug.Log("ChangeMovementMode.");
        transform.Find("GPU_Flock_Draw").GetComponent<BoidMovementController>().enabled = false;
        transform.Find("Target").GetComponent<Klak.Motion.BrownianMotion>().enabled = true;
    }
}
