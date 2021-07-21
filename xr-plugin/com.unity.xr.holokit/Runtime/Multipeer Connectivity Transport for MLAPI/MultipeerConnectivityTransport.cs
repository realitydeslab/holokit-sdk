using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using MLAPI.Transports.Tasks;

namespace MLAPI.Transports.MultipeerConnectivity
{
    /// <summary>
    /// A full data packet received from a peer through multipeer connectivity network.
    /// </summary>
    public struct PeerDataPacket
    {
        public ulong clientId;
        public byte[] data;
        public int dataArrayLength;
        public int channel;
    }
    
    public class MultipeerConnectivityTransport : NetworkTransport
    {
        // This class is a singleton.
        private static MultipeerConnectivityTransport _instance;

        public static MultipeerConnectivityTransport Instance { get { return _instance; } }

        /// <summary>
        /// The client Id of this machine in the local network.
        /// </summary>
        private ulong m_ClientId;

        public ulong ClientId => m_ClientId;

        /// <summary>
        /// The server Id. For the host, the server id and the client id are the same.
        /// </summary>
        private ulong m_ServerId = 0;

        public override ulong ServerClientId => m_ServerId;

        /// <summary>
        /// Is there a new connection request to be sent?
        /// This variable is only used by clients.
        /// </summary>
        private bool m_SentConnectionRequest = false;

        /// <summary>
        /// Is there is new disconnection message to be handled?
        /// This variable is only used by the server.
        /// </summary>
        private bool m_ReceivedDisconnectionMessage = false;

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
        [SerializeField]
        private string m_ServiceType = "ar-collab";

        /// <summary>
        /// Initialize the MultipeerSession instance on Objective-C side.
        /// </summary>
        /// <param name="serviceType"></param>
        /// <param name="peerID"></param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerInit(string serviceType, string peerID);

        /// <summary>
        /// Release the MultipeerSession instance on Objective-C side.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerShutdown();

        /// <summary>
        /// Start to browse other peers through the multipeer connectivity network.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerStartBrowsing();

        /// <summary>
        /// Expose the device to other browsers in the multipeer connectivity network.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerStartAdvertising();

        /// <summary>
        /// This delegate function is only called by a client.
        /// </summary>
        delegate void MultipeerSendConnectionRequestForMLAPI(ulong serverId);
        [AOT.MonoPInvokeCallback(typeof(MultipeerSendConnectionRequestForMLAPI))]
        static void OnMultipeerConnectionRequestSentForMLAPI(ulong serverId)
        {
            // This delegate function gets called from Objective-C side when AR collaboration started.
            // We start MLAPI connection right after that.
            Debug.Log("[MultipeerConnectivityTransport]: send multipeer connection request to MLAPI.");

            Instance.m_ServerId = serverId;
            Instance.m_SentConnectionRequest = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetMultipeerSendConnectionRequestForMLAPIDelegate(MultipeerSendConnectionRequestForMLAPI callback);

        /// <summary>
        /// This delegate function is only called by the server.
        /// This function gets called when the server notices that a client is
        /// disconnected through multipeer connectivity network.
        /// </summary>
        delegate void MultipeerDisconnectionMessageReceivedForMLAPI(ulong clientId);
        [AOT.MonoPInvokeCallback(typeof(MultipeerDisconnectionMessageReceivedForMLAPI))]
        static void OnMultipeerDisconnectionMessageReceivedForMLAPI(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: received a disconnection message from client {clientId}.");

            Instance.m_ReceivedDisconnectionMessage = true;
            Instance.m_LastDisconnectedClientId = clientId;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetMultipeerDisconnectionMessageReceivedForMLAPIDelegate(MultipeerDisconnectionMessageReceivedForMLAPI callback);

        /// <summary>
        /// Send MLAPI data to a peer through multipeer connectivity.
        /// </summary>
        /// <param name="clientId">The client Id of the recipient</param>
        /// <param name="data">Raw data to be sent</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerSendDataForMLAPI(ulong clientId, byte[] data, int dataArrayLength, int channel);

        /// <summary>
        /// The delegate called when peer data is received through multipeer connectivity network.
        /// </summary>
        /// <param name="clientId">The peerId who sends the data</param>
        /// <param name="data">The raw data</param>
        /// <param name="dataArrayLength">The length of the data array</param>
        /// <param name="channel">MLAPI NetworkChannel</param>
        delegate void PeerDataReceivedForMLAPI(ulong clientId, IntPtr dataPtr, int dataArrayLength, int channel);
        [AOT.MonoPInvokeCallback(typeof(PeerDataReceivedForMLAPI))]
        static void OnPeerDataReceivedForMLAPI(ulong clientId, IntPtr dataPtr, int dataArrayLength, int channel)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: did receive a new peer data packet from {clientId}, {(NetworkChannel)channel}");
            // https://stackoverflow.com/questions/25572221/callback-byte-from-native-c-to-c-sharp
            byte[] data = new byte[dataArrayLength];
            Marshal.Copy(dataPtr, data, 0, dataArrayLength);

            // Enqueue this data packet
            PeerDataPacket newPeerDataPacket = new PeerDataPacket() { clientId = clientId, data = data, dataArrayLength = dataArrayLength, channel = channel };
            Instance.m_PeerDataPacketQueue.Enqueue(newPeerDataPacket);
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetPeerDataReceivedForMLAPIDelegate(PeerDataReceivedForMLAPI callback);

        /// <summary>
        /// Tell all peers connected through the multipeer connectivity network to disconnect.
        /// This function should only be called on the server side.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerDisconnectAllPeersForMLAPI();

        /// <summary>
        /// Disconnect from the multipeer connectivity network.
        /// This function should only be called by a client.
        /// </summary>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerDisconnectForMLAPI();

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
            UnityHoloKit_SetMultipeerSendConnectionRequestForMLAPIDelegate(OnMultipeerConnectionRequestSentForMLAPI);
            UnityHoloKit_SetMultipeerDisconnectionMessageReceivedForMLAPIDelegate(OnMultipeerDisconnectionMessageReceivedForMLAPI);
            UnityHoloKit_SetPeerDataReceivedForMLAPIDelegate(OnPeerDataReceivedForMLAPI);
        }

        public override void Init()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Init() {Time.time}");
            // Randomly generate a client Id for this machine.
            // The random generator picks a random int between 1 and 1,000,000,
            // therefore, it is very unlikely that we get a duplicate client Id.
            var randomGenerator = new System.Random((int)(Time.time * 1000));
            ulong newClientId = (ulong)randomGenerator.Next(1, 1000000);
            m_ClientId = newClientId;

            // Init the multipeer session on objective-c++ side.
            if (m_ServiceType == null)
            {
                Debug.Log("[MultipeerConnectivityTransport]: failed to init multipeer session because the service type is null.");
            }
            UnityHoloKit_MultipeerInit(m_ServiceType, newClientId.ToString());
        }

        public override SocketTasks StartServer()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: StartServer() {Time.time}");
            m_ServerId = m_ClientId;
            UnityHoloKit_MultipeerStartBrowsing();
            return SocketTask.Done.AsTasks();
        }

        public override SocketTasks StartClient()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: StartClient() {Time.time}");
            UnityHoloKit_MultipeerStartAdvertising();
            return SocketTask.Done.AsTasks();
        }

        public override NetworkEvent PollEvent(out ulong clientId, out NetworkChannel networkChannel, out ArraySegment<byte> payload, out float receiveTime)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: PollEvent() {Time.time}");

            // Send a connection request to the server as a client.
            if (m_SentConnectionRequest && !NetworkManager.Singleton.IsServer)
            {
                m_SentConnectionRequest = false;
                clientId = m_ServerId;
                networkChannel = NetworkChannel.DefaultMessage;
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Connect;
            }

            // Send a disconnection message to the server as a client.
            if (m_ReceivedDisconnectionMessage && NetworkManager.Singleton.IsServer)
            {
                m_ReceivedDisconnectionMessage = false;
                clientId = m_LastDisconnectedClientId;
                networkChannel = NetworkChannel.DefaultMessage;
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Disconnect;
            }

            // Handle the incoming messages.
            if (m_PeerDataPacketQueue.Count > 0)
            {
                PeerDataPacket dataPacket = m_PeerDataPacketQueue.Dequeue();
                clientId = dataPacket.clientId;
                networkChannel = (NetworkChannel)dataPacket.channel;
                payload = new ArraySegment<byte>(dataPacket.data, 0, dataPacket.dataArrayLength);
                receiveTime = Time.realtimeSinceStartup;
                // TODO: I don't know if this is correct.
                return NetworkEvent.Data;
            }

            // We do nothing here if nothing happens.
            clientId = 0;
            networkChannel = NetworkChannel.ChannelUnused;
            receiveTime = Time.realtimeSinceStartup;
            return NetworkEvent.Nothing;
        }

        public override void Send(ulong clientId, ArraySegment<byte> data, NetworkChannel networkChannel)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: Send() with network channel {networkChannel} to clientId {clientId}");

            // Convert ArraySegment to Array
            // https://stackoverflow.com/questions/5756692/arraysegment-returning-the-actual-segment-c-sharp
            byte[] newArray = new byte[data.Count];
            Array.Copy(data.Array, data.Offset, newArray, 0, data.Count);
            UnityHoloKit_MultipeerSendDataForMLAPI(clientId, newArray, data.Count, (int)networkChannel);
        }

        public override ulong GetCurrentRtt(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: GetCurrentRtt() {Time.time}");
            // TODO: Implement this.
            return 0;
        }

        public override void DisconnectLocalClient()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: DisconnectLocalClient() {Time.time}");

            // TODO: To be tested.
            UnityHoloKit_MultipeerDisconnectForMLAPI();
        }

        public override void DisconnectRemoteClient(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: DisconnectRemoteClient() {Time.time}");

            // TODO: This is not correct, we should disconnect one client at a time.
            UnityHoloKit_MultipeerDisconnectAllPeersForMLAPI();
        }

        public override void Shutdown()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Shutdown() {Time.time}");
            UnityHoloKit_MultipeerShutdown();
        }
    }
}