using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI.Transports.Tasks;
using System;
using System.Runtime.InteropServices;

namespace MLAPI.Transports.MultipeerConnectivity
{
    public class MultipeerConnectivityTransport : NetworkTransport
    {
        private static MultipeerConnectivityTransport _instance;

        public static MultipeerConnectivityTransport Instance { get { return _instance; } }

        /// <summary>
        /// Is this machine the host in the local network?
        /// </summary>
        private bool m_IsHost;

        /// <summary>
        /// The client Id of this machine in the local network.
        /// </summary>
        private ulong m_ClientId;

        private bool m_IsNewPeerConnected = false;
        private ulong m_newPeerId;

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
        /// Dealing with ARCollaborationSynchronized callback function.
        /// </summary>
        delegate void MultipeerConnectionStartedForMLAPI(ulong peerId);

        [AOT.MonoPInvokeCallback(typeof(MultipeerConnectionStartedForMLAPI))]
        static void OnMultipeerConnectionStartedForMLAPI(ulong peerId)
        {
            // This delegate function gets called from Objective-C side when AR collaboration started.
            // We start MLAPI connection right after that.
            Debug.Log("[MultipeerConnectivityTransport]: multipeer connection started.");

            MultipeerConnectivityTransport.Instance.m_IsNewPeerConnected = true;
            MultipeerConnectivityTransport.Instance.m_newPeerId = peerId;
            Debug.Log($"[MultipeerConnectivityTransport]: connected peerId {peerId}");
        }

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetMultipeerConnectionStartedForMLAPIDelegate(MultipeerConnectionStartedForMLAPI callback);

        // TODO: I don't know what it is
        public override ulong ServerClientId => 0;

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

        public override SocketTasks StartServer()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: StartServer() {Time.time}");
            m_IsHost = true;
            UnityHoloKit_MultipeerStartBrowsing();
            return SocketTask.Done.AsTasks();
        }

        public override SocketTasks StartClient()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: StartClient() {Time.time}");
            m_IsHost = false;
            UnityHoloKit_MultipeerStartAdvertising();
            return SocketTask.Done.AsTasks();
        }

        public override NetworkEvent PollEvent(out ulong clientId, out NetworkChannel networkChannel, out ArraySegment<byte> payload, out float receiveTime)
        {
            //Debug.Log($"[MultipeerConnectivityTransport]: PollEvent() {Time.time}");
            // We do nothing here.
            clientId = 0;
            networkChannel = NetworkChannel.ChannelUnused;
            receiveTime = Time.realtimeSinceStartup;
            return NetworkEvent.Nothing;
        }

        public override void Send(ulong clientId, ArraySegment<byte> data, NetworkChannel networkChannel)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Send() {Time.time}");
            throw new NotImplementedException();
        }

        public override void Init()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Init() {Time.time}");
            // Randomly generate a client Id for this machine.
            // The random generator picks a random int between 1 and 1,000,000,
            // therefore, it is very unlikely that we get a duplicate client Id.
            var randomGenerator = new System.Random((int)(Time.time * 1000));
            ulong myClientId = (ulong)randomGenerator.Next(1, 1000000);

            // Init the multipeer session in objective-c side.
            if (m_ServiceType == null)
            {
                Debug.Log("[MultipeerConnectivityTransport]: failed to init multipeer session because service type is null.");
            }
            UnityHoloKit_MultipeerInit(m_ServiceType, myClientId.ToString());
        }

        public override void Shutdown()
        {
            Debug.Log($"[MultipeerConnectivityTransport]: Shutdown() {Time.time}");
            throw new NotImplementedException();
        }

        public override ulong GetCurrentRtt(ulong clientId)
        {
            Debug.Log($"[MultipeerConnectivityTransport]: GetCurrentRtt() {Time.time}");
            throw new NotImplementedException();
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

        private void Start()
        {
            // Register delegates
            UnityHoloKit_SetMultipeerConnectionStartedForMLAPIDelegate(OnMultipeerConnectionStartedForMLAPI);
        }

        private void Update()
        {
            if (m_IsNewPeerConnected)
            {
                InvokeOnTransportEvent(NetworkEvent.Connect, m_newPeerId, NetworkChannel.DefaultMessage, default, Time.time);
                m_IsNewPeerConnected = false;
            }
        }
    }
}