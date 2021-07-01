using MLAPI;
using MLAPI.Messaging;
using MLAPI.NetworkVariable;
using UnityEngine;
using UnityEngine.VFX;

namespace HelloWorld
{
    public class HelloWorldPlayer : NetworkBehaviour
    {

        [SerializeField]
        private GameObject vfx;

        public NetworkVariableVector3 Position = new NetworkVariableVector3(new NetworkVariableSettings
        {
            WritePermission = NetworkVariablePermission.ServerOnly,
            ReadPermission = NetworkVariablePermission.Everyone
        });

        public override void NetworkStart()
        {
            Move();
        }

        public void Move()
        {
            Debug.Log("[HelloWorldPlayer]: Move()");
            if (NetworkManager.Singleton.IsServer)
            {
                var randomPosition = GetRandomPositionOnPlane();
                transform.position = randomPosition;
                Position.Value = randomPosition;
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
            return new Vector3(Random.Range(-3f, 3f), 1f, Random.Range(-3f, 3f));
        }

        void Update()
        {
            transform.position = Position.Value;
        }

        [ServerRpc]
        private void SpawnVfxServerRpc()
        {
            SpawnVfxClientRpc();
        }

        [ClientRpc]
        private void SpawnVfxClientRpc()
        {
            Instantiate(vfx, transform.position, transform.rotation);
        }
    }
}