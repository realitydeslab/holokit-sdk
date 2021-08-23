using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Connection;
using MLAPI.Transports.MultipeerConnectivity;

public class PhantomBuddhasGameManager : HoloKitGameManager
{

    public override void StartNetwork(string networkRole)
    {
        MultipeerConnectivityTransport.Instance.IdentityString = "PhantomBuddhas";

        base.StartNetwork(networkRole);
    }
}
