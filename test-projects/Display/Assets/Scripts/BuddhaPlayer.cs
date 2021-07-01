using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using UnityEngine.XR.HoloKit;

public class BuddhaPlayer : NetworkBehaviour
{

    [SerializeField] private GameObject m_HostHandSpherePrefab;

    private NetworkVariableVector3 HostHandCenterNetworkVariable = new NetworkVariableVector3();

    private GameObject m_HostHandSphere;

    public override void NetworkStart()
    {
        //SpawnHostHandSphere();
    }

    private void Start()
    {
        HostHandCenterNetworkVariable.Settings.ReadPermission = NetworkVariablePermission.Everyone;
        HostHandCenterNetworkVariable.Settings.WritePermission = NetworkVariablePermission.Everyone;

        if (IsServer)
        {
            var holoKitHandTracking = GameObject.Find("HoloKitHandTracking");
            if (holoKitHandTracking)
            {
                var script = holoKitHandTracking.GetComponent<HoloKitHandTracking>();
                if (script)
                {
                    script.m_HandCenter = GameObject.Find("HandSphere");
                    //Debug.Log($"fuck {script.m_HandCenter}");
                }
            }
        }
        else if (IsClient)
        {
            var holoKitHandTracking = GameObject.Find("HoloKitHandTracking");
            if (holoKitHandTracking)
            {
                var script = holoKitHandTracking.GetComponent<HoloKitHandTracking>();
                if (script)
                {
                    script.enabled = false;
                }
            }
        }
    }

    private void Update()
    {
        if (IsServer)
        {
            var handCenter = GameObject.Find("HandSphere");
            if (handCenter != null)
            {
                //Debug.Log($"[BuddhaPlayer]: Server side - Update host hand center {handCenter.transform.position}.");
                HostHandCenterNetworkVariable.Value = handCenter.transform.position;
            }
        }
        else if (IsClient)
        {
            //Debug.Log($"[BuddhaPlayer]: Client side - Log the host hand position {HostHandCenterNetworkVariable.Value}.");
            GameObject.Find("HandSphere").transform.position = HostHandCenterNetworkVariable.Value;
            //Debug.Log($"[BuddhaPlayer]: host hand sphere position {m_HostHandSphere.transform.position}");
        }
        
    }

    public void SpawnHostHandSphere()
    {
        SpawnHostHandSphereServerRpc();
    }

    [ServerRpc]
    private void SpawnHostHandSphereServerRpc()
    {
        SpawnHostHandSphereClientRpc();
    }

    [ClientRpc]
    private void SpawnHostHandSphereClientRpc()
    {
        m_HostHandSphere = Instantiate(m_HostHandSpherePrefab, new Vector3(0f, 0f, 1f), new Quaternion(0f, 0f, 0f, 1f));
    }
}
