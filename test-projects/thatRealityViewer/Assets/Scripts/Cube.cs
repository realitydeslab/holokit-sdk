using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.HoloKit;

public class Cube : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        GetComponent<MeshRenderer>().material.SetTexture("_BaseMap", HoloKitSettings.Instance.SecondCameraRenderTexture);
    }
}
