using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using Unity.Netcode;

namespace Netcode.Transports.MultipeerConnectivity
{
    /// <summary>
    /// A full data packet received from a peer through multipeer connectivity network.
    /// </summary>
    public struct PeerDataPacket
    {
        public ulong clientId;
        public byte[] data;
        public int dataArrayLength;
    }
    
    public class MultipeerConnectivityTransport : NetworkTransport
    {       
        // This class is a singleton.
        private static MultipeerConnectivityTransport _instance;

        public static MultipeerConnectivityTransport Instance { get { return _instance; } }

        /// <summary>
        /// The serverId of the local network.
        /// </summary>
        private ulong m_ServerTransportId = 0;

        public override ulong ServerClientId => m_ServerTransportId;

        private string m_DeviceName;

        public string DeviceName => m_DeviceName;

        /// <summary>
        /// Is there a new connection request to be sent?
        /// This variable is only used by clients.
        /// </summary>
        private bool m_PeerDidConnect = false;

        private ulong m_ConnectedPeerTransportId = 0;

        /// <summary>
        /// Is there is new disconnection message to be handled?
        /// This variable is only used by the server.
        /// </summary>
        private bool m_PeerDidDisconnect = false;

        /// <summary>
        /// The client Id of the pending disconnection mesasge.
        /// </summary>
        private ulong m_DisconnectedPeerTransportId = 0;

        /// <summary>
        /// The queue storing all peer data packets received through the network so that
        /// the data packets can be processed in order.
        /// </summary>
        private Queue<PeerDataPacket> m_PeerDataPacketQueue = new Queue<PeerDataPacket>();

        /// <summary>
        /// The service type for multipeer connectivity.
        /// Only devices with the same service type get connected.
        /// </summary>
        //[SerializeField]
        private string m_ServiceType = "holokit-collab";

        /// <summary>
        /// If the system is executing the Ping Pong scheme.
        /// </summary>
        public bool IsRttAvailable = true;

        /// <summary>
        /// The lastest round trip time to the server as a client.
        /// This variable is not used on the server side.
        /// </summary>
        [HideInInspector]
        public double CurrentRtt = 0f;

        /// <summary>
        /// The time when the system sents the last Ping message.
        /// </summary>
        private float m_LastPingTime = 0f;

        public float LastPingTime
        {
            get => m_LastPingTime;
        }

        /// <summary>
        /// The time interval for sending Ping messages.
        /// </summary>
        private const float k_PingInterval = 2f;

        private Dictionary<ulong, string> m_TransportId2DeviceNameMap = new();

        public Dictionary<ulong, string> TransportId2DeviceNameMap => m_TransportId2DeviceNameMap;

        private List<ulong> m_CurrentAvailableServers = new();

        public List<ulong> CurrentAvailableHosts => m_CurrentAvailableServers;

        /// <summary>
        /// If server, it stores all clients' transportIds.
        /// If client, it only stores the server's.
        /// </summary>
        private List<ulong> m_ConnectedPeerTransportIds = new();

        /// <summary>
        /// Initialize the MultipeerSession instance on native iOS side.
        /// </summary>
        /// <param name="peerName"></param>
        /// <param name="serviceType"></param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCInitialize(string serviceType);

        /// <summary>
        /// Start to browse other peers through the multipeer connectivity network.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStartBrowsing();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStopBrowsing();

        /// <summary>
        /// Expose the device to other browsers in the multipeer connectivity network.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStartAdvertising();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStopAdvertising();

        [DllImport("__Internal")]
        private static extern ulong UnityHoloKit_MCGetServerClientId();

        /// <summary>
        /// Send MLAPI data to a peer through multipeer connectivity.
        /// </summary>
        /// <param name="transportId">The client Id of the recipient</param>
        /// <param name="data">Raw data to be sent</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendData(ulong transportId, byte[] data, int dataArrayLength, int channel);

        /// <summary>
        /// Send a Ping message to a specific client.
        /// </summary>
        /// <param name="transportId">The client Id</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendPingMessage(ulong transportId);

        /// <summary>
        /// Disconnect from the multipeer connectivity network.
        /// This function should only be called by a client.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCDisconnectLocalClient();

        /// <summary>
        /// Notify a peer to disconnect.
        /// This function should only be called on the server side.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCDisconnectRemoteClient(ulong transportId);

        /// <summary>
        /// Release the MultipeerSession instance on Objective-C side.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCShutdown();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCInvitePeer(ulong clientId);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendConnectionMessage2Client(ulong clientId);

        delegate void BrowserDidFindPeer(ulong transportId, string deviceName);
        [AOT.MonoPInvokeCallback(typeof(BrowserDidFindPeer))]
        static void OnBrowserDidFindPeer(ulong transportId, string deviceName)
        {
            Debug.Log($"[MCTransport] OnBrowserDidFindPeer {transportId}");
            if (!Instance.m_TransportId2DeviceNameMap.ContainsKey(transportId))
            {
                Instance.m_TransportId2DeviceNameMap[transportId] = deviceName;
            }
            if (!Instance.m_CurrentAvailableServers.Contains(transportId))
            {
                Instance.m_CurrentAvailableServers.Add(transportId);
            }
            Instance.BrowserDidFindPeerEvent?.Invoke(transportId, deviceName);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetBrowserDidFindPeerDelegate(BrowserDidFindPeer callback);

        delegate void BrowserDidLosePeer(ulong transportId);
        [AOT.MonoPInvokeCallback(typeof(BrowserDidLosePeer))]
        static void OnBrowserDidLosePeer(ulong transportId)
        {
            Instance.m_CurrentAvailableServers.Remove(transportId);
            Instance.BrowserDidLosePeerEvent?.Invoke(transportId);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetBrowserDidLosePeerDelegate(BrowserDidLosePeer callback);

        delegate void PeerDidConnect(ulong transportId, string deviceName);
        [AOT.MonoPInvokeCallback(typeof(PeerDidConnect))]
        static void OnPeerDidConnect(ulong transportId, string deviceName)
        {   
            Instance.m_PeerDidConnect = true;
            Instance.m_ConnectedPeerTransportId = transportId;
            Instance.m_ServerTransportId = transportId;
            Instance.NewPeerDidConnectEvent?.Invoke(transportId, deviceName);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetPeerDidConnectDelegate(PeerDidConnect callback);

        /// <summary>
        /// The delegate called when peer data is received through multipeer connectivity network.
        /// </summary>
        /// <param name="transportId">The peerId who sends the data</param>
        /// <param name="data">The raw data</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        delegate void DidReceivePeerData(ulong transportId, IntPtr dataPtr, int dataArrayLength);
        [AOT.MonoPInvokeCallback(typeof(DidReceivePeerData))]
        static void OnDidReceivePeerData(ulong transportId, IntPtr dataPtr, int dataArrayLength)
        {   
            if (NetworkManager.Singleton.IsServer && !Instance.m_ConnectedPeerTransportIds.Contains(transportId))
            {
                Instance.m_PeerDidConnect = true;
                Instance.m_ConnectedPeerTransportId = transportId;
                Instance.m_ConnectedPeerTransportIds.Add(transportId);
            }

            byte[] data = new byte[dataArrayLength];
            Marshal.Copy(dataPtr, data, 0, dataArrayLength);
            PeerDataPacket newPeerDataPacket = new PeerDataPacket() { clientId = transportId, data = data, dataArrayLength = dataArrayLength };
            Instance.m_PeerDataPacketQueue.Enqueue(newPeerDataPacket);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceivePeerDataDelegate(DidReceivePeerData callback);

        /// <summary>
        /// This delegate function is called when a Pong message is received. The unit is millisecond.
        /// </summary>
        /// <param name="transportId">The sender of the Pong message</param>
        delegate void DidReceivePongMessage(ulong transportId, double rtt);
        [AOT.MonoPInvokeCallback(typeof(DidReceivePongMessage))]
        static void OnDidReceivePongMessage(ulong transportId, double rtt)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: Current Rtt {Instance.CurrentRtt}");
            Instance.CurrentRtt = rtt;
            Instance.RttDidUpdateEvent?.Invoke(rtt);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceivePongMessageDelegate(DidReceivePongMessage callback);

        delegate void PeerDidDisconnect(ulong transportId);
        [AOT.MonoPInvokeCallback(typeof(PeerDidDisconnect))]
        static void OnPeerDidDisconnect(ulong transportId)
        {
            Debug.Log($"[MCTransport] OnPeerDidDisconnect({transportId})");
            Instance.m_PeerDidDisconnect = true;
            Instance.m_DisconnectedPeerTransportId = transportId;
            Instance.m_ConnectedPeerTransportIds.Remove(transportId);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetPeerDidDisconnectDelegate(PeerDidDisconnect callback);

        delegate void DidDisconnectFromServer();
        [AOT.MonoPInvokeCallback(typeof(DidDisconnectFromServer))]
        static void OnDidDisconnectFromServer()
        {
            Debug.Log("[MCTransport] DidDisconnectFromServer");
            Instance.DidDisconnectFromServerEvent?.Invoke();
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidDisconnectFromServerDelegate(DidDisconnectFromServer callback);

        [DllImport("__Internal")]
        private static extern string UnityHoloKit_GetDeviceName();

        public event Action<ulong, string> BrowserDidFindPeerEvent;

        public event Action<ulong> BrowserDidLosePeerEvent;

        public event Action<ulong, string> NewPeerDidConnectEvent;

        public event Action<double> RttDidUpdateEvent;

        public event Action DidDisconnectFromServerEvent;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(this.gameObject);
            }
            else
            {
                _instance = this;
            }
        }

        private void OnEnable()
        {
            // Register delegates
            UnityHoloKit_SetBrowserDidFindPeerDelegate(OnBrowserDidFindPeer);
            UnityHoloKit_SetBrowserDidLosePeerDelegate(OnBrowserDidLosePeer);
            UnityHoloKit_SetPeerDidConnectDelegate(OnPeerDidConnect);
            UnityHoloKit_SetDidReceivePeerDataDelegate(OnDidReceivePeerData);
            UnityHoloKit_SetDidReceivePongMessageDelegate(OnDidReceivePongMessage);
            UnityHoloKit_SetPeerDidDisconnectDelegate(OnPeerDidDisconnect);
            UnityHoloKit_SetDidDisconnectFromServerDelegate(OnDidDisconnectFromServer);
        }

        private void OnDestroy()
        {
            //UnityHoloKit_MCShutdown();
        }

        /// <summary>
        /// Initialize was called before starting host or server.
        /// </summary>
        public override void Initialize()
        {
            Debug.Log("[MCTransport] Initialize");
            // Init the multipeer session on objective-c++ side.
            if (m_ServiceType == null)
            {
                Debug.Log("[MultipeerConnectivityTransport]: failed to initialize multipeer session because property service type is null.");
                return;
            }
            UnityHoloKit_MCInitialize(m_ServiceType);
            m_DeviceName = UnityHoloKit_GetDeviceName();
        }

        public override bool StartServer()
        {
            Debug.Log("[MCTransport]: StartServer");
            UnityHoloKit_MCStartAdvertising();
            return true;
        }

        public override bool StartClient()
        {
            Debug.Log("[MCTransport]: StartClient");
            UnityHoloKit_MCStartBrowsing();
            return true;
        }

        private void Update()
        {
            if (NetworkManager.Singleton.IsConnectedClient && IsRttAvailable)
            {
                if (Time.time - m_LastPingTime > k_PingInterval)
                {
                    m_LastPingTime = Time.time;
                    //UnityHoloKit_MCSendPingMessage(m_ServerClientId);
                }
            }
        }

        public override NetworkEvent PollEvent(out ulong transportId, out ArraySegment<byte> payload, out float receiveTime)
        {
            if (m_PeerDidConnect)
            {
                m_PeerDidConnect = false;
                transportId = m_ConnectedPeerTransportId;
                payload = new ArraySegment<byte>();
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Connect;
            }

            // Handle the incoming messages.
            if (m_PeerDataPacketQueue.Count > 0)
            {
                PeerDataPacket dataPacket = m_PeerDataPacketQueue.Dequeue();
                transportId = dataPacket.clientId;
                payload = new ArraySegment<byte>(dataPacket.data, 0, dataPacket.dataArrayLength);
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Data;
            }

            if (m_PeerDidDisconnect)
            {
                m_PeerDidDisconnect = false;
                transportId = m_DisconnectedPeerTransportId;
                payload = new ArraySegment<byte>();
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Disconnect;
            }

            // We do nothing here if nothing happens.
            transportId = 0;
            payload = new ArraySegment<byte>();
            receiveTime = Time.realtimeSinceStartup;
            return NetworkEvent.Nothing;
        }

        public override void Send(ulong transportId, ArraySegment<byte> data, NetworkDelivery networkDelivery)
        {
            // Convert ArraySegment to Array
            // https://stackoverflow.com/questions/5756692/arraysegment-returning-the-actual-segment-c-sharp
            byte[] newArray = new byte[data.Count];
            Array.Copy(data.Array, data.Offset, newArray, 0, data.Count);
            UnityHoloKit_MCSendData(transportId, newArray, data.Count, (int)networkDelivery);

            //Debug.Log($"[MPCTransport] send data with size {data.Count} and NetworkDelivery {networkDelivery}");
        }

        public override ulong GetCurrentRtt(ulong transportId)
        {
            return (ulong)CurrentRtt;
        }

        public override void DisconnectLocalClient()
        {
            Debug.Log("[MCTransport] DisconnectLocalClient");
            UnityHoloKit_MCDisconnectLocalClient();
        }

        public override void DisconnectRemoteClient(ulong transportId)
        {
            Debug.Log($"[MCTransport] DisconnectRemoteClient {transportId}");
            UnityHoloKit_MCDisconnectRemoteClient(transportId);
        }

        public override void Shutdown()
        {
            Debug.Log("[MCTransport] Shutdown");
            UnityHoloKit_MCShutdown();

            // Do the refresh job
            m_ServerTransportId = 0;
            m_DeviceName = null;
            m_PeerDidConnect = false;
            m_ConnectedPeerTransportId = 0;
            m_PeerDidDisconnect = false;
            m_DisconnectedPeerTransportId = 0;
            m_PeerDataPacketQueue.Clear();
            m_TransportId2DeviceNameMap.Clear();
            m_CurrentAvailableServers.Clear();
            m_ConnectedPeerTransportIds.Clear();
        }

        public void StopAdvertising()
        {
            UnityHoloKit_MCStopAdvertising();
        }

        public void StopBrowsing()
        {
            UnityHoloKit_MCStopBrowsing();
        }

        public void InvitePeer(ulong transportId)
        {
            UnityHoloKit_MCInvitePeer(transportId);
        }
    }
}