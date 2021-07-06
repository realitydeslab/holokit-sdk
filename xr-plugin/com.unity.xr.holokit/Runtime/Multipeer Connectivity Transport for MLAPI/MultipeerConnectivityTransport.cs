using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI.Transports.Tasks;
using System;
using System.Runtime.InteropServices;

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
        private ulong m_MyClientId;

        private ulong m_ServerId = 0;

        public override ulong ServerClientId => m_ServerId;

        private bool m_SendingConnectionRequest = false;

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
        /// This is a list which holds all connected peers' clientIds.
        /// </summary>
        private List<ulong> m_ConnectedPeers;

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerInit(string serviceType, string peerID);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerStartBrowsing();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_MultipeerStartAdvertising();

        /// <summary>
        /// This delegate function is only called on the non-server side.
        /// </summary>
        delegate void MultipeerSendConnectionRequestForMLAPI(ulong serverId);
        [AOT.MonoPInvokeCallback(typeof(MultipeerSendConnectionRequestForMLAPI))]
        static void OnMultipeerConnectionRequestSentForMLAPI(ulong serverId)
        {
            // This delegate function gets called from Objective-C side when AR collaboration started.
            // We start MLAPI connection right after that.
            Debug.Log("[MultipeerConnectivityTransport]: request multipeer connection request.");

            MultipeerConnectivityTransport.Instance.m_ServerId = serverId;
            MultipeerConnectivityTransport.Instance.m_SendingConnectionRequest = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetMultipeerSendConnectionRequestForMLAPIDelegate(MultipeerSendConnectionRequestForMLAPI callback);

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
            // https://stackoverflow.com/questions/25572221/callback-byte-from-native-c-to-c-sharp
            byte[] data = new byte[dataArrayLength];
            Marshal.Copy(dataPtr, data, 0, dataArrayLength);

            //Debug.Log($"[MultipeerConnectivityTransport]: MLAPI data received from the Unity side with dataArrayLength {dataArrayLength} and channel {(NetworkChannel)channel}");
            //Debug.Log($"[MultipeerConnectivityTransport]: data array length {data.Length} and the whole data array is {data[0]}, {data[1]}, {data[2]}, {data[3]}, {data[4]}, " +
            //    $"{data[5]}, {data[6]}, {data[7]}, {data[8]}, {data[9]}");

            // Enqueue this data packet
            PeerDataPacket newPeerDataPacket = new PeerDataPacket() { clientId = clientId, data = data, dataArrayLength = dataArrayLength, channel = channel };
            MultipeerConnectivityTransport.Instance.m_PeerDataPacketQueue.Enqueue(newPeerDataPacket);
            //Debug.Log($"[MultipeerConnectivityTransport]: received a new peer data packet {clientId}, {(NetworkChannel)channel}");
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetPeerDataReceivedForMLAPIDelegate(PeerDataReceivedForMLAPI callback);

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
            m_MyClientId = newClientId;

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
            m_ServerId = m_MyClientId;
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

            // Notify MLAPI that a peer is connected.
            if (!NetworkManager.Singleton.IsServer && m_SendingConnectionRequest)
            {
                m_SendingConnectionRequest = false;
                clientId = m_ServerId;
                networkChannel = NetworkChannel.DefaultMessage;
                receiveTime = Time.realtimeSinceStartup;
                return NetworkEvent.Connect;
            }

            if (m_PeerDataPacketQueue.Count > 0)
            {
                PeerDataPacket dataPacket = m_PeerDataPacketQueue.Dequeue();
                //Debug.Log($"[MultipeerConnectivityTransport]: dequeue peer data packet from {dataPacket.clientId}.");
                clientId = dataPacket.clientId;
                networkChannel = (NetworkChannel)dataPacket.channel;
                payload = new ArraySegment<byte>(dataPacket.data, 0, dataPacket.dataArrayLength);
                receiveTime = Time.realtimeSinceStartup;
                // TODO: I don't know if this is correct.
                return NetworkEvent.Data;
            }

            // TODO: dealing with disconnection

            // We do nothing here if nothing happens.
            clientId = 0;
            networkChannel = NetworkChannel.ChannelUnused;
            receiveTime = Time.realtimeSinceStartup;
            return NetworkEvent.Nothing;
        }

        public override void Send(ulong clientId, ArraySegment<byte> data, NetworkChannel networkChannel)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: Send() with network channel {networkChannel} to clientId {clientId}");
            //Debug.Log($"[MultipeerConnectivityTransport]: data.Array {data.Array}, data.Count {data.Count}, data.Offset {data.Offset}");
            // https://stackoverflow.com/questions/10940883/c-converting-byte-array-to-string-and-printing-out-to-console
            //Debug.Log($"[MultipeerConnectivityTransport]: byte array {System.Text.Encoding.UTF8.GetString(data.Array)}");

            // The MLAPI has the data and called this method, we need to send this data
            // to the right peer through multipeer connectivity.
            // The first message sent by the client when connected is of the network channel "Internal".
            // Convert ArraySegment to Array
            // https://stackoverflow.com/questions/5756692/arraysegment-returning-the-actual-segment-c-sharp
            byte[] newArray = new byte[data.Count];
            Array.Copy(data.Array, data.Offset, newArray, 0, data.Count);
            //Debug.Log($"[MultipeerConnectivityTransport]: the size of the new array is {newArray.Length}");
            UnityHoloKit_MultipeerSendDataForMLAPI(clientId, newArray, data.Count, (int)networkChannel);
        }

        public override void Shutdown()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Shutdown() {Time.time}");
            throw new NotImplementedException();
        }

        public override ulong GetCurrentRtt(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: GetCurrentRtt() {Time.time}");
            return 0;
        }

        public override void DisconnectLocalClient()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: DisconnectLocalClient() {Time.time}");
            throw new NotImplementedException();
        }

        public override void DisconnectRemoteClient(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: DisconnectRemoteClient() {Time.time}");
            throw new NotImplementedException();
        }
    }
}