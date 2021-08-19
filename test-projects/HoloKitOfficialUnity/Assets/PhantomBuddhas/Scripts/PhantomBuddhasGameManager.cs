using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.HoloKit;
using MLAPI;
using MLAPI.Transports.MultipeerConnectivity;

public class PhantomBuddhasGameManager : HoloKitGameManager
{

    protected override void StartGame()
    {

    }

    public override void StartNetwork(string networkRole)
    {
        MultipeerConnectivityTransport.Instance.IdentityString = "PhantomBuddhas";

        base.StartNetwork(networkRole);
    }
}
