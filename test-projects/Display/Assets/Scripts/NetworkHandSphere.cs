using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;

public class NetworkHandSphere : NetworkBehaviour
{

    private Transform arCamera;

    private void Start()
    {
        arCamera = Camera.main.transform;
    }

    private void Update()
    {
        //Debug.Log($"[NetworkHandSphere]: the owner of this object is {OwnerClientId}");
        if (IsOwner)
        {
            transform.LookAt(arCamera.forward);
            transform.position = GameObject.Find("HandSphere").transform.position;
        }
        
    }
}
