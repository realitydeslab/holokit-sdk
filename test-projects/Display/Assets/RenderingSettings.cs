using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR.ARFoundation;

public class RenderingSettings : MonoBehaviour
{
    ARCameraBackground camBackground;

    // Start is called before the first frame update
    void Start()
    {
        camBackground = FindObjectOfType<ARCameraBackground>();
        if (camBackground)
        {
            Debug.Log("hey");
        }
        camBackground.enabled = true;
    }

    // Update is called once per frame
    void Update()
    {

    }    
}