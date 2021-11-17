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
        private ulong m_ServerClientId = 0;

        public override ulong ServerClientId => m_ServerClientId;

        /// <summary>
        /// Is there a new connection request to be sent?
        /// This variable is only used by clients.
        /// </summary>
        private bool m_DidNewPeerConnect = false;

        private ulong m_NewConnectedPeerClientId = 0;

        /// <summary>
        /// Is there is new disconnection message to be handled?
        /// This variable is only used by the server.
        /// </summary>
        private bool m_DidReceiveDisconnectionMessage = false;

        /// <summary>
        /// The client Id of the pending disconnection mesasge.
        /// </summary>
        private ulong m_LastDisconnectedClientId;

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

        private Dictionary<ulong, string> m_ClientId2DeviceNameMap = new();

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
        /// <param name="clientId">The client Id of the recipient</param>
        /// <param name="data">Raw data to be sent</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendData(ulong clientId, byte[] data, int dataArrayLength, int channel);

        /// <summary>
        /// Send a Ping message to a specific client.
        /// </summary>
        /// <param name="clientId">The client Id</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendPingMessage(ulong clientId);

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
        private static extern void UnityHoloKit_MCDisconnectRemoteClient(ulong clientId);

        /// <summary>
        /// Release the MultipeerSession instance on Objective-C side.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCShutdown();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCInvitePeer(ulong clientId);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendConnectionMessage2Client(ulong clientId);

        delegate void BrowserDidFindPeer(string deviceName, ulong clientId);
        [AOT.MonoPInvokeCallback(typeof(BrowserDidFindPeer))]
        static void OnBrowserDidFindPeer(string deviceName, ulong clientId)
        {
            Instance.BrowserDidFindPeerEvent?.Invoke(deviceName, clientId);
            Instance.m_ClientId2DeviceNameMap.Add(clientId, deviceName);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetBrowserDidFindPeerDelegate(BrowserDidFindPeer callback);

        delegate void BrowserDidLosePeer(ulong clientId);
        [AOT.MonoPInvokeCallback(typeof(BrowserDidLosePeer))]
        static void OnBrowserDidLosePeer(ulong clientId)
        {
            Instance.BrowserDidLosePeerEvent?.Invoke(clientId);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetBrowserDidLosePeerDelegate(BrowserDidLosePeer callback);

        /// <summary>
        /// Send connection request message to the server.
        /// This delegate function is only called by a client.
        /// </summary>
        delegate void NewPeerDidConnect(ulong clientId);
        [AOT.MonoPInvokeCallback(typeof(NewPeerDidConnect))]
        static void OnNewPeerDidConnect(ulong clientId)
        {
            Debug.Log($"New peer client id {clientId}");
            Instance.m_NewConnectedPeerClientId = clientId;
            if (!NetworkManager.Singleton.IsServer)
            {
                Instance.m_ServerClientId = clientId;
            }
            Instance.m_DidNewPeerConnect = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetNewPeerDidConnectDelegate(NewPeerDidConnect callback);

        /// <summary>
        /// The delegate called when peer data is received through multipeer connectivity network.
        /// </summary>
        /// <param name="clientId">The peerId who sends the data</param>
        /// <param name="data">The raw data</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        delegate void DidReceivePeerData(ulong clientId, IntPtr dataPtr, int dataArrayLength);
        [AOT.MonoPInvokeCallback(typeof(DidReceivePeerData))]
        static void OnDidReceivePeerData(ulong clientId, IntPtr dataPtr, int dataArrayLength)
        {
            // https://stackoverflow.com/questions/25572221/callback-byte-from-native-c-to-c-sharp
            byte[] data = new byte[dataArrayLength];
            Marshal.Copy(dataPtr, data, 0, dataArrayLength);

            // Enqueue this data packet
            PeerDataPacket newPeerDataPacket = new PeerDataPacket() { clientId = clientId, data = data, dataArrayLength = dataArrayLength };
            Instance.m_PeerDataPacketQueue.Enqueue(newPeerDataPacket);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceivePeerDataDelegate(DidReceivePeerData callback);

        /// <summary>
        /// This delegate function is called when a Pong message is received. The unit is millisecond.
        /// </summary>
        /// <param name="clientId">The sender of the Pong message</param>
        delegate void DidReceivePongMessage(ulong clientId, double rtt);
        [AOT.MonoPInvokeCallback(typeof(DidReceivePongMessage))]
        static void OnDidReceivePongMessage(ulong clientId, double rtt)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: Current Rtt {Instance.CurrentRtt}");
            Instance.CurrentRtt = rtt;
            Instance.RttDidUpdateEvent?.Invoke(rtt);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceivePongMessageDelegate(DidReceivePongMessage callback);

        /// <summary>
        /// This delegate function is only called on the server.
        /// This function gets called when the server notices that a client is
        /// disconnected through multipeer connectivity network.
        /// </summary>
        delegate void DidReceiveDisconnectionMessageFromClient(ulong clientId);
        [AOT.MonoPInvokeCallback(typeof(DidReceiveDisconnectionMessageFromClient))]
        static void OnDidReceiveDisconnectionMessageFromClient(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: received a disconnection message from client {clientId}.");

            Instance.m_DidReceiveDisconnectionMessage = true;
            Instance.m_LastDisconnectedClientId = clientId;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceiveDisconnectionMessageFromClientDelegate(DidReceiveDisconnectionMessageFromClient callback);

        public delegate void BrowserDidFindPeerDelegate(string deviceName, ulong clientId);
        public event BrowserDidFindPeerDelegate BrowserDidFindPeerEvent;

        public delegate void BrowserDidLosePeerDelegate(ulong clientId);
        public event BrowserDidLosePeerDelegate BrowserDidLosePeerEvent;

        public delegate void NewPeerDidConnectDelegate(ulong clientId);
        public event NewPeerDidConnectDelegate NewPeerDidConnectEvent;

        public delegate void RttDidUpdateDelegate(double rtt);
        public event RttDidUpdateDelegate RttDidUpdateEvent;

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
            UnityHoloKit_SetNewPeerDidConnectDelegate(OnNewPeerDidConnect);
            UnityHoloKit_SetDidReceivePeerDataDelegate(OnDidReceivePeerData);
            UnityHoloKit_SetDidReceivePongMessageDelegate(OnDidReceivePongMessage);
            UnityHoloKit_SetDidReceiveDisconnectionMessageFromClientDelegate(OnDidReceiveDisconnectionMessageFromClient);
        }

        private void OnDisable()
        {
            // Unregister events
        }

        private void Start()
        {
            // Register events
        }

        /// <summary>
        /// Initialize was called before starting host or server.
        /// </summary>
        public override void Initialize()
        {
            // Init the multipeer session on objective-c++ side.
            if (m_ServiceType == null)
            {
                Debug.Log("[MultipeerConnectivityTransport]: failed to initialize multipeer session because property service type is null.");
                return;
            }
           
            UnityHoloKit_MCInitialize(m_ServiceType);
        }

        public override bool StartServer()
        {
            m_ServerClientId = UnityHoloKit_MCGetServerClientId();
            UnityHoloKit_MCStartAdvertising();
            return true;
        }

        public override bool StartClient()
        {
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
                    UnityHoloKit_MCSendPingMessage(m_ServerClientId);
                }
            }
        }

        public override NetworkEvent PollEvent(out ulong clientId, out ArraySegment<byte> payload, out float receiveTime)
        {
            // Send a connection request to the server as a client.
            if (m_DidNewPeerConnect)
            {
                m_DidNewPeerConnect = false;
                clientId = m_NewConnectedPeerClientId;
                payload = new ArraySegment<byte>();
                receiveTime = Time.realtimeSinceStartup;
                NewPeerDidConnectEvent?.Invoke(m_NewConnectedPeerClientId);
                if (NetworkManager.Singleton.IsServer)
                {
                    UnityHoloKit_MCSendConnectionMessage2Client(clientId);
                }
                return NetworkEvent.Connect;
            }

            // Handle the incoming messages.
            if (m_PeerDataPacketQueue.Count > 0)
            {
                PeerDataPacket dataPacket = m_PeerDataPacketQueue.Dequeue();
                clientId = dataPacket.clientId;
                payload = new ArraySegment<byte>(dataPacket.data, 0, dataPacket.dataArrayLength);
                receiveTime = Time.realtimeSinceStartup;
                // TODO: I don't know if this is correct.
                return NetworkEvent.Data;
            }

            // Send a disconnection message to the server as a client.
            if (m_DidReceiveDisconnectionMessage && NetworkManager.Singleton.IsServer)
            {
                m_DidReceiveDisconnectionMessage = false;
                clientId = m_LastDisconnectedClientId;
                payload = new ArraySegment<byte>();
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Disconnect;
            }

            // We do nothing here if nothing happens.
            clientId = 0;
            payload = new ArraySegment<byte>();
            receiveTime = Time.realtimeSinceStartup;
            return NetworkEvent.Nothing;
        }

        public override void Send(ulong clientId, ArraySegment<byte> data, NetworkDelivery networkDelivery)
        {
            // Convert ArraySegment to Array
            // https://stackoverflow.com/questions/5756692/arraysegment-returning-the-actual-segment-c-sharp
            byte[] newArray = new byte[data.Count];
            Array.Copy(data.Array, data.Offset, newArray, 0, data.Count);
            UnityHoloKit_MCSendData(clientId, newArray, data.Count, (int)networkDelivery);
        }

        public override ulong GetCurrentRtt(ulong clientId)
        {
            return (ulong)CurrentRtt;
        }

        public override void DisconnectLocalClient()
        {
            // TODO: To be tested.
            UnityHoloKit_MCDisconnectLocalClient();
        }

        public override void DisconnectRemoteClient(ulong clientId)
        {
            // TODO: This is not correct, we should disconnect one client at a time.
            UnityHoloKit_MCDisconnectRemoteClient(clientId);
        }

        public override void Shutdown()
        {
            UnityHoloKit_MCShutdown();
        }

        public void StopAdvertising()
        {
            UnityHoloKit_MCStopAdvertising();
        }

        public void StopBrowsing()
        {
            UnityHoloKit_MCStopBrowsing();
        }

        public void InvitePeer(ulong clientId)
        {
            UnityHoloKit_MCInvitePeer(clientId);
        }
    }
}