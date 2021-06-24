using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI.Transports.Tasks;
using System;

namespace MLAPI.Transports.MultipeerConnectivity
{
    public class MultipeerConnectivityTransport : NetworkTransport
    {
        [SerializeField]
        private bool m_IsHost;

        public override SocketTasks StartServer()
        {
            throw new System.NotImplementedException();
        }

        public override SocketTasks StartClient()
        {
            throw new System.NotImplementedException();
        }

        public override NetworkEvent PollEvent(out ulong clientId, out NetworkChannel networkChannel, out ArraySegment<byte> payload, out float receiveTime)
        {
            throw new NotImplementedException();
        }

        public override void Send(ulong clientId, ArraySegment<byte> data, NetworkChannel networkChannel)
        {
            throw new NotImplementedException();
        }

        public override void Init()
        {
            throw new NotImplementedException();
        }

        public override void Shutdown()
        {
            throw new NotImplementedException();
        }

        public override ulong ServerClientId => throw new NotImplementedException();

        public override void DisconnectLocalClient()
        {
            throw new NotImplementedException();
        }

        public override ulong GetCurrentRtt(ulong clientId)
        {
            throw new NotImplementedException();
        }

        public override void DisconnectRemoteClient(ulong clientId)
        {
            throw new NotImplementedException();
        }
    }
}