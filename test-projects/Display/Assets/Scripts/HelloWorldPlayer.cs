using System;
using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using UnityEngine;
using UnityEngine.VFX;

namespace HelloWorld
{
    public class HelloWorldPlayer : NetworkBehaviour
    {

        [SerializeField] private GameObject m_VfxPrefab;

        [SerializeField] private NetworkObject m_FlyingCubePrefab;

        private int m_FrameCount;

        public NetworkVariableVector3 Position = new NetworkVariableVector3(new NetworkVariableSettings
        {
            WritePermission = NetworkVariablePermission.ServerOnly,
            ReadPermission = NetworkVariablePermission.Everyone
        });

        public override void NetworkStart()
        {
            Move();
        }

        private void Start()
        {

        }

        void Update()
        {
            if (m_FrameCount < 60)
            {
                transform.position = Position.Value;
            }
            m_FrameCount++;
        }

        public void Move()
        {
            if (NetworkManager.Singleton.IsServer)
            {
                //var randomPosition = GetRandomPositionOnPlane();
                //transform.position = randomPosition;
                //Position.Value = randomPosition;

                Position.Value = GetRandomPositionOnPlane();
            }
            else
            {
                SubmitPositionRequestServerRpc();
            }
        }

        public void SpawnVfx()
        {
            SpawnVfxServerRpc();
        }

        [ServerRpc]
        void SubmitPositionRequestServerRpc(ServerRpcParams rpcParams = default)
        {
            Position.Value = GetRandomPositionOnPlane();
        }

        static Vector3 GetRandomPositionOnPlane()
        {
            return new Vector3(UnityEngine.Random.Range(-3f, 3f), 2.0f, UnityEngine.Random.Range(-3f, 3f));
        }

        [ServerRpc]
        private void SpawnVfxServerRpc()
        {
            SpawnVfxClientRpc();
        }

        [ClientRpc]
        private void SpawnVfxClientRpc()
        {
            Instantiate(m_VfxPrefab, transform.position, transform.rotation);
        }

        [ServerRpc]
        public void SpawnFlyingCubeServerRpc()
        {
            var newFlyingCube = Instantiate(m_FlyingCubePrefab, transform.position, Quaternion.identity);
            newFlyingCube.SpawnWithOwnership(OwnerClientId);
        }

        public void AddForce(Vector3 direction, float magnitude)
        {
            Debug.Log("[HelloWorldPlayer]: AddForce()");
            GetComponent<Rigidbody>().AddForce(direction * magnitude);
        }
    }
}