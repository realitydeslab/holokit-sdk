using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using UnityEngine.XR.HoloKit;

public class HostHandSphereController : NetworkBehaviour
{
    void Start()
    {
        if (IsServer)
        {
            var holoKitHandTracking = GameObject.Find("HoloKitHandTracking");
            if (holoKitHandTracking)
            {
                var script = holoKitHandTracking.GetComponent<HoloKitHandTracking>();
                if (script)
                {
                    script.m_HandCenter = this.gameObject;
                }
            }
        }
    }

    void Update()
    {
        
    }
}
