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

        [SerializeField]
        private GameObject vfx;

        private bool isMoving = false;

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
            transform.position = Position.Value;

            if (isMoving)
            {
                float theta = Time.frameCount / 10.0f;
                transform.position = new Vector3((float)Math.Cos(theta), 0.0f, (float)Math.Sin(theta));
            }
        }

        public void Move()
        {
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

        public void StartMoving()
        {
            isMoving = !isMoving;
        }

        [ServerRpc]
        void SubmitPositionRequestServerRpc(ServerRpcParams rpcParams = default)
        {
            Position.Value = GetRandomPositionOnPlane();
        }

        static Vector3 GetRandomPositionOnPlane()
        {
            return new Vector3(UnityEngine.Random.Range(-3f, 3f), 1f, UnityEngine.Random.Range(-3f, 3f));
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