using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.HoloKit;

public class MpcUI : MonoBehaviour
{
    [SerializeField] private GameObject _prefab;

    private void Start()
    {
        MultipeerConnectivityApi.BrowserDidFindPeerEvent += OnBrowserDidFindPeer;
    }

    public void StartHost()
    {
        MultipeerConnectivityApi.StartAdvertising();
    }

    public void StartClient()
    {
        MultipeerConnectivityApi.StartBrowsing();
    }

    private void OnBrowserDidFindPeer(ulong transportId, string deviceName)
    {
        Debug.Log("Fuck");
        Instantiate(_prefab);
    }
}
