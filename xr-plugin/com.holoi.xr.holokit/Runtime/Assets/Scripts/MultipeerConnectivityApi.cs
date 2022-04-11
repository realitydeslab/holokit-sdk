using System.Collections.Generic;
using System.Runtime.InteropServices;
using System;

namespace UnityEngine.XR.HoloKit
{
    public static class MultipeerConnectivityApi
    {
        // If you change this, you will also need to change the plist.
        public const string ServiceType = "magikverse-app";

        public static Dictionary<ulong, string> BrowsedPeersTransportId2DeviceNameMap;

        public static bool IsBrowsing;

        public static bool IsAdvertising;

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

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetPhotonRoomName(string roomName);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetDidReceivePhotonRoomNameDelegate(Action<string> callback);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetDidReceiveHostLocalIpAddressDelegate(Action<string> callback);

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_MPCIsHost();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MPCSetDidReceiveARWorldMapDelegate(Action callback);

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
            Debug.Log($"[MPC] Browser did lose peer with transport id: {transportId}");
            BrowsedPeersTransportId2DeviceNameMap.Remove(transportId);
            BrowserDidLosePeerEvent?.Invoke(transportId);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<string>))]
        private static void OnDidReceivePhotonRoomName(string roomName)
        {
            Debug.Log($"[MPC] Received Photon room name {roomName}");
            DidReceivePhotonRoomNameEvent?.Invoke(roomName);
        }

        [AOT.MonoPInvokeCallback(typeof(Action<string>))]
        private static void OnDidReceiveHostLocalIpAddress(string ip)
        {
            DidReceiveHostLocalIpAddressEvent?.Invoke(ip);
        }

        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnDidReceiveARWorldMap()
        {
            Debug.Log("[MPC] Did receive ARWorldMap");
            DidReceiveARWorldMapEvent?.Invoke();
        }

        public static event Action<ulong, string> BrowserDidFindPeerEvent;

        public static event Action<ulong> BrowserDidLosePeerEvent;

        public static event Action<string> DidReceivePhotonRoomNameEvent;

        public static event Action<string> DidReceiveHostLocalIpAddressEvent;

        public static event Action DidReceiveARWorldMapEvent;

        public static void StartBrowsing()
        {
            Debug.Log("[MPC] StartBrowsing");
            BrowsedPeersTransportId2DeviceNameMap = new();
            UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(OnBrowserDidFindPeer);
            UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(OnBrowserDidLosePeer);
            UnityHoloKit_MPCSetDidReceivePhotonRoomNameDelegate(OnDidReceivePhotonRoomName);
            UnityHoloKit_MPCSetDidReceiveHostLocalIpAddressDelegate(OnDidReceiveHostLocalIpAddress);
            UnityHoloKit_MPCSetDidReceiveARWorldMapDelegate(OnDidReceiveARWorldMap);

            UnityHoloKit_MPCInitialize(ServiceType);
            UnityHoloKit_MPCStartBrowsing();
            IsBrowsing = true;
        }

        public static void StartAdvertising()
        {
            Debug.Log("[MPC] StartAdvertising");
            UnityHoloKit_MPCInitialize(ServiceType);
            UnityHoloKit_MPCStartAdvertising();
            IsAdvertising = true;
        }

        public static void StopBrowsing()
        {
            Debug.Log("[MPC] StopBrowsing");
            UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(null);
            UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(null);
            UnityHoloKit_MPCSetDidReceivePhotonRoomNameDelegate(null);
            UnityHoloKit_MPCSetDidReceiveHostLocalIpAddressDelegate(null);
            UnityHoloKit_MPCSetDidReceiveARWorldMapDelegate(null);

            UnityHoloKit_MPCStopBrowsing();
            UnityHoloKit_MPCDeinitialize();
            IsBrowsing = false;
        }

        public static void StopAdvertising()
        {
            Debug.Log("[MPC] StopAdvertising");
            UnityHoloKit_MPCStopAdvertising();
            UnityHoloKit_MPCDeinitialize();
            IsAdvertising = false;
        }

        public static void SetPhotonRoomName(string roomName)
        {
            UnityHoloKit_MPCSetPhotonRoomName(roomName);
        }

        public static void JoinSession(ulong hostTransportId)
        {
            UnityHoloKit_MPCInvitePeer(hostTransportId);
        }

        public static bool IsHost()
        {
            return UnityHoloKit_MPCIsHost();
        }

        // Disable MPC if necessary.
        public static void Shutdown()
        {
            if (IsBrowsing)
                StopBrowsing();
            else if (IsAdvertising)
                StopAdvertising();
        }
    }
}
