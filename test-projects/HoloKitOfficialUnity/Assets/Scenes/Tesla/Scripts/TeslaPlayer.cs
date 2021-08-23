using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;
using UnityEngine.XR.ARFoundation;

public class TeslaPlayer : NetworkBehaviour
{
    [SerializeField] private NetworkObject m_TeslaPrefab;

    [SerializeField] private NetworkObject m_HandPrefab;

    private void Start()
    {
        if (IsServer)
        {
            // Open the ray caster
            var rayCaster = FindObjectOfType<ARTapToPlaceObject>().gameObject;
            rayCaster.SetActive(true);
        }
        else
        {
            FindObjectOfType<VFXLineRenderer>().gameObject.SetActive(false);
            //FindObjectOfType<ARPlaneManager>().enabled = false;
            FindObjectOfType<MenuSimple>().gameObject.SetActive(false);
        }

        var handInstance = Instantiate(m_HandPrefab);
        handInstance.SpawnWithOwnership(OwnerClientId);
    }

    
    public void SpawnTesla()
    {
        if (!IsServer) return;

        var position = FindObjectOfType<ARTapToPlaceObject>().PlacementPose.position;
        var rotation = FindObjectOfType<ARTapToPlaceObject>().PlacementPose.rotation;
        var go = Instantiate(m_TeslaPrefab, position, rotation);
        go.Spawn();

        //
        FindObjectOfType<VFXLineRenderer>().gameObject.SetActive(false);
        //FindObjectOfType<ARPlaneManager>().enabled = false;
        FindObjectOfType<MenuSimple>().gameObject.SetActive(false);
    }

}
