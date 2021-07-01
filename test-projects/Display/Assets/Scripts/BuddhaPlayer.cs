using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using UnityEngine.XR.HoloKit;
using UnityEngine.VFX;

public class BuddhaPlayer : NetworkBehaviour
{

    private NetworkVariableVector3 HostHandCenterNetworkVariable = new NetworkVariableVector3();

    [SerializeField] private List<GameObject> m_VFXs = new List<GameObject>();

    private List<GameObject> m_CurrentVFXs = new List<GameObject>();

    public override void NetworkStart()
    {
        SpawnVFXs();
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

        foreach(GameObject vfx in m_CurrentVFXs)
        {
            vfx.GetComponent<VisualEffect>().SetVector3("HandCenter", GameObject.Find("HandSphere").transform.position);
        }
    }

    public void SpawnVFXs()
    {
        SpawnVFXsServerRpc();
    }

    [ServerRpc]
    private void SpawnVFXsServerRpc()
    {
        SpawnVFXsClientRpc();
    }

    [ClientRpc]
    private void SpawnVFXsClientRpc()
    {
        foreach (GameObject vfx in m_VFXs)
        {
            var newVfx = Instantiate(vfx);
            m_CurrentVFXs.Add(newVfx);
            //newVfx.GetComponent<HandBinder>().target = GameObject.Find("HandSphere").transform;
        }
    }
}
