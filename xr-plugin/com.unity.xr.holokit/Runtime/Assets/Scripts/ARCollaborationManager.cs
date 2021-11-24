using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Netcode;
using Unity.Collections;
using UnityEngine.XR.ARKit;
using UnityEngine.XR.ARFoundation;
using System.Runtime.InteropServices;

namespace UnityEngine.XR.HoloKit {
    public class ARCollaborationManager : NetworkBehaviour
    {
        private static ARCollaborationManager _instance;

        public static ARCollaborationManager Instance { get { return _instance; } }

        private FixedString64Bytes m_SessionId;

        public NetworkList<FixedString64Bytes> SessionIds;

        private bool m_ShouldAddSessionId = false;

        private Transform m_CenterEyePoint;

        [SerializeField] GameObject m_MagicPrefab;

        [SerializeField] GameObject m_MagicPrefab2;

        [SerializeField] NetworkObject m_MagicNetworkPrefab;

        [SerializeField] NetworkObject m_MagicNetworkPrefab2;

        private bool m_ShouldSpawnMagic = false;

        private Vector3 m_MagicPosition;

        private Quaternion m_MagicRotation;

        private int m_MagicClientId;

        public Dictionary<ulong, Transform> ClientId2ARParticipantTransformMap = new Dictionary<ulong, Transform>();

        delegate void ARSessionDidStart();
        [AOT.MonoPInvokeCallback(typeof(ARSessionDidStart))]
        private static void OnARSessionDidStart()
        {
            ARSession session = FindObjectOfType<ARSession>();
            ARKitSessionSubsystem subsystem = session.subsystem as ARKitSessionSubsystem;
            Instance.m_SessionId = new FixedString64Bytes(subsystem.sessionId.ToString());
            Debug.Log($"[ARCollaborationManager] ARSession start with sessionId {Instance.m_SessionId}");
            Instance.m_ShouldAddSessionId = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARSessionDidStartDelegate(ARSessionDidStart callback);

        delegate void DidReceiveMagicAnchor(int clientId, int magicIndex, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float rotW);
        [AOT.MonoPInvokeCallback(typeof(DidReceiveMagicAnchor))]
        private static void OnDidReceiveMagicAnchor(int clientId, int magicIndex, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float rotW)
        {
            Debug.Log("[ARCollaborationManager] OnDidReceiveMagicAnchor");
            Instance.m_ShouldSpawnMagic = true;
            Instance.m_MagicPosition = new Vector3(posX, posY, posZ);
            Instance.m_MagicRotation = new Quaternion(rotX, rotY, rotZ, rotW);
            Instance.m_MagicClientId = clientId;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetDidReceiveMagicAnchorDelegate(DidReceiveMagicAnchor callback);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_AddNativeAnchor(string anchorName, float[] position, float[] rotation);

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

            UnityHoloKit_SetARSessionDidStartDelegate(OnARSessionDidStart);
            UnityHoloKit_SetDidReceiveMagicAnchorDelegate(OnDidReceiveMagicAnchor);

            SessionIds = new NetworkList<FixedString64Bytes>();

            ARSession session = FindObjectOfType<ARSession>();
            ARKitSessionSubsystem subsystem = session.subsystem as ARKitSessionSubsystem;
            subsystem.collaborationRequested = true;
        }

        public override void OnNetworkSpawn()
        {
            Debug.Log("[ARCollaborationManager] OnNetworkSpawn");

            m_CenterEyePoint = GameObject.Find("CenterEyePoint").transform;
        }

        [ServerRpc(RequireOwnership = false)]
        private void AddSessionIdServerRpc(int clientId, FixedString64Bytes sessionId)
        {
            Debug.Log($"[ARCollaborationManager] AddSessionIdServerRpc {clientId} and {sessionId}");
            while (Instance.SessionIds.Count <= clientId)
            {
                Instance.SessionIds.Add("");
            }
            Instance.SessionIds[clientId] = sessionId;
        }

        private void Update()
        {
            //Debug.Log($"[CenterEyePoint] position {m_CenterEyePoint.position} and rotation {m_CenterEyePoint.rotation}");

            if (m_ShouldAddSessionId)
            {
                AddSessionIdServerRpc((int)NetworkManager.Singleton.LocalClientId, m_SessionId);
                m_ShouldAddSessionId = false;
            }

            if (m_ShouldSpawnMagic)
            {
                Instantiate(m_MagicPrefab, m_MagicPosition, m_MagicRotation);
                Debug.Log($"[magic1] position {m_MagicPosition} and rotation {m_MagicRotation}");
                m_ShouldSpawnMagic = false;
                //if (m_MagicClientId != (int)NetworkManager.LocalClientId)
                //{
                //    Debug.Log($"[ARCollaborationManager] this is not my magic, it is from {m_MagicClientId}");
                //    Transform transform = ClientId2ARParticipantTransformMap[(ulong)m_MagicClientId];
                //    Vector3 offset = new Vector3(0f, 0f, 0.6f);
                //    Vector3 position = transform.position + transform.TransformVector(offset);
                //    Quaternion rotation = transform.rotation;
                //    Debug.Log($"[magic2] position {position} and rotation {rotation}");
                //    Instantiate(m_MagicPrefab2, position, rotation);
                //}
            }

            if (Input.touchCount == 1)
            {
                if (Input.touches[0].phase == TouchPhase.Began)
                {
                    Vector3 offset = new Vector3(0f, 0f, 0.6f);
                    Vector3 position = m_CenterEyePoint.position + m_CenterEyePoint.TransformVector(offset);
                    Quaternion rotation = m_CenterEyePoint.rotation;
                    float[] pos = { position.x, position.y, position.z };
                    float[] rot = { rotation.x, rotation.y, rotation.z, rotation.w };
                    UnityHoloKit_AddNativeAnchor($"magic-{NetworkManager.LocalClientId}", pos, rot);

                    SpawnNetworkMagicServerRpc(NetworkManager.LocalClientId);

                    SpawnNetworkMagic2ServerRpc(NetworkManager.LocalClientId, position, rotation);
                }
            }
        }

        public void DidAddARParticipantAnchor(ulong clientId, Transform tranform)
        {
            Debug.Log($"[ARCollaborationManager] did add ARParticipantAnchor of client {clientId}");
            if (!ClientId2ARParticipantTransformMap.ContainsKey(clientId))
            {
                ClientId2ARParticipantTransformMap.Add(clientId, tranform);
            }
        }

        [ServerRpc(RequireOwnership = false)]
        private void SpawnNetworkMagicServerRpc(ulong clientId)
        {
            var magicInstance = Instantiate(m_MagicNetworkPrefab);
            magicInstance.SpawnWithOwnership(clientId);
        }

        [ServerRpc(RequireOwnership = false)]
        private void SpawnNetworkMagic2ServerRpc(ulong clientId, Vector3 position, Quaternion rotation) {
            var magicInstance = Instantiate(m_MagicNetworkPrefab2, position, rotation);
            magicInstance.SpawnWithOwnership(clientId);
        }

        public void AddOriginAnchor()
        {
            float[] pos = { 0f, 0f, 0f };
            float[] rot = { 0f, 0f, 0f, 1f };
            UnityHoloKit_AddNativeAnchor("origin", pos, rot);
        }
    }
}