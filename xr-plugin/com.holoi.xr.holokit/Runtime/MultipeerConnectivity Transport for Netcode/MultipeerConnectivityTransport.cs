using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using Unity.Netcode;

namespace Netcode.Transports.MultipeerConnectivity
{
    /// <summary>
    /// A data packet received from a peer through MPC.
    /// </summary>
    public struct PeerDataPacket
    {
        public ulong transportId;
        public byte[] data;
        public int dataArrayLength;
    }
    
    public class MultipeerConnectivityTransport : NetworkTransport
    {
        private static MultipeerConnectivityTransport _instance;

        public static MultipeerConnectivityTransport Instance { get { return _instance; } }

        private ulong m_ServerTransportId = 0;

        public override ulong ServerClientId => m_ServerTransportId;

        private bool m_IsHost;

        private bool m_PeerDidConnect;

        private ulong m_ConnectedPeerTransportId;

        private bool m_PeerDidDisconnect;

        private ulong m_DisconnectedPeerTransportId;

        // Server only
        private Dictionary<ulong, bool> m_TransportId2ConnectionStatusMap;

        /// <summary>
        /// The queue storing all peer data packets received through the network so that
        /// the data packets can be processed in order.
        /// </summary>
        private Queue<PeerDataPacket> m_PeerDataPacketQueue = new Queue<PeerDataPacket>();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCSendData(ulong transportId, byte[] data, int dataArrayLength, int channel);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCDisconnectLocalClient();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCDisconnectRemoteClient(ulong transportId);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStopAdvertising();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCStopBrowsing();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MCShutdown();

        /// <summary>
        /// The delegate called when peer data is received through multipeer connectivity network.
        /// </summary>
        /// <param name="transportId">The peerId who sends the data</param>
        /// <param name="data">The raw data</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        delegate void DidReceivePeerData(ulong transportId, IntPtr dataPtr, int dataArrayLength);
        [AOT.MonoPInvokeCallback(typeof(DidReceivePeerData))]
        private static void OnDidReceivePeerData(ulong transportId, IntPtr dataPtr, int dataArrayLength)
        {
            if (Instance.m_IsHost && !Instance.m_TransportId2ConnectionStatusMap.ContainsKey(transportId))
            {
                Instance.m_TransportId2ConnectionStatusMap.Add(transportId, true);
                Instance.m_ConnectedPeerTransportId = transportId;
                Instance.m_PeerDidConnect = true;
            }

            byte[] data = new byte[dataArrayLength];
            Marshal.Copy(dataPtr, data, 0, dataArrayLength);
            PeerDataPacket newPeerDataPacket = new PeerDataPacket() { transportId = transportId, data = data, dataArrayLength = dataArrayLength };
            Instance.m_PeerDataPacketQueue.Enqueue(newPeerDataPacket);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceivePeerDataDelegate(DidReceivePeerData callback);

        delegate void ClientDidDisconnect(ulong transportId);
        [AOT.MonoPInvokeCallback(typeof(ClientDidDisconnect))]
        private static void OnClientDidDisconnect(ulong transportId)
        {
            Instance.m_DisconnectedPeerTransportId = transportId;
            Instance.m_PeerDidDisconnect = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetClientDidDisconnectDelegate(ClientDidDisconnect callback);

        delegate void DidDisconnectFromHost();
        [AOT.MonoPInvokeCallback(typeof(DidDisconnectFromHost))]
        private static void OnDidReceiveDisconnectionMessage()
        {
            Instance.m_DisconnectedPeerTransportId = Instance.m_ServerTransportId;
            Instance.m_PeerDidDisconnect = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidDisconnectFromHostDelegate(DidDisconnectFromHost callback);

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

            m_PeerDidConnect = false;
            m_PeerDidDisconnect = false;
            m_TransportId2ConnectionStatusMap = new();
            UnityHoloKit_SetDidReceivePeerDataDelegate(OnDidReceivePeerData);
            UnityHoloKit_SetClientDidDisconnectDelegate(OnClientDidDisconnect);
            UnityHoloKit_SetDidDisconnectFromHostDelegate(OnDidReceiveDisconnectionMessage);
        }

        public override void Initialize()
        {
            Debug.Log("[MCTransport] Initialize");
        }

        public override bool StartServer()
        {
            Debug.Log("[MCTransport]: StartServer");
            m_IsHost = true;
            return true;
        }

        public override bool StartClient()
        {
            Debug.Log("[MCTransport]: StartClient");
            m_IsHost = false;
            return true;
        }

        public override NetworkEvent PollEvent(out ulong transportId, out ArraySegment<byte> payload, out float receiveTime)
        {
            if (m_PeerDidConnect)
            {
                Debug.Log($"[MPCTransport] peer did connect {m_ConnectedPeerTransportId}");
                m_PeerDidConnect = false;
                transportId = m_ConnectedPeerTransportId;
                payload = new ArraySegment<byte>();
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Connect;
            }

            // Handle incoming messages
            if (m_PeerDataPacketQueue.Count > 0)
            {
                PeerDataPacket dataPacket = m_PeerDataPacketQueue.Dequeue();
                transportId = dataPacket.transportId;
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
        }

        public override ulong GetCurrentRtt(ulong transportId)
        {
            return 0;
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
            m_PeerDidConnect = false;
            m_PeerDidDisconnect = false;
            m_TransportId2ConnectionStatusMap = new();
            m_PeerDataPacketQueue.Clear();
        }

        public void DidReceiveConnectionInvitation(ulong hostTransportId)
        {
            m_ServerTransportId = hostTransportId;
            m_ConnectedPeerTransportId = hostTransportId;
            m_PeerDidConnect = true;
        }
    }
}