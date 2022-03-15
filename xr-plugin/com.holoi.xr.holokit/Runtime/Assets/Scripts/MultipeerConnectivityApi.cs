using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using System;

namespace UnityEngine.XR.HoloKit
{
    public static class MultipeerConnectivityApi
    {
        // If you change this, you will also need to change the plist.
        public const string ServiceType = "magikverse-app";

        public static Dictionary<ulong, string> BrowsedPeersTransportId2DeviceNameMap;

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCInitialize(string serviceType);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCStartBrowsing();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCStartAdvertising();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCStopBrowsing();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCStopAdvertising();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCDeinitialize();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(Action<ulong, string> callback);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(Action<ulong> callback);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCInvitePeer(ulong transportId);

        [AOT.MonoPInvokeCallback(typeof(Action<ulong, string>))]
        private static void OnBrowserDidFindPeer(ulong transportId, string deviceName)
        {
            //Debug.Log($"[MPC] Browser did find peer with transport id: {transportId} " +
            //    $"and device name: {deviceName}");
            BrowsedPeersTransportId2DeviceNameMap.Add(transportId, deviceName);
            BrowserDidFindPeerEvent?.Invoke(transportId, deviceName);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<ulong>))]
        private static void OnBrowserDidLosePeer(ulong transportId)
        {
            //Debug.Log($"[MPC] Browser did lose peer with transport id: {transportId}");
            BrowsedPeersTransportId2DeviceNameMap.Remove(transportId);
            BrowserDidLosePeerEvent?.Invoke(transportId);
        }

        public static event Action<ulong, string> BrowserDidFindPeerEvent;

        public static event Action<ulong> BrowserDidLosePeerEvent;

        public static void StartBrowsing()
        {
            BrowsedPeersTransportId2DeviceNameMap = new();
            UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(OnBrowserDidFindPeer);
            UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(OnBrowserDidLosePeer);
            UnityHoloKit_MPCInitialize(ServiceType);
            UnityHoloKit_MPCStartBrowsing();
        }

        public static void StartAdvertising()
        {
            UnityHoloKit_MPCInitialize(ServiceType);
            UnityHoloKit_MPCStartAdvertising();
        }
    }
}
