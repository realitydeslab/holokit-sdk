using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;

public class NetworkHandSphere : NetworkBehaviour
{

    private void Update()
    {
        //Debug.Log($"[NetworkHandSphere]: the owner of this object is {OwnerClientId}");
        if (IsOwner)
        {
            transform.LookAt(Camera.main.transform.forward);
            transform.position = GameObject.Find("HandSphere").transform.position;
        }
        
    }
}
