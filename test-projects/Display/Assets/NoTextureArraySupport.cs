using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class NoTextureArraySupport : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        var displays = new List<XRDisplaySubsystem>();
        SubsystemManager.GetInstances(displays);
        if (displays.Count > 0)
        {
            displays[0].singlePassRenderingDisabled = true;
            Debug.Log("Got display subsystem!");
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
