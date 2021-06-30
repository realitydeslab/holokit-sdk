using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitAnchorManager : MonoBehaviour
    {

        //private static HoloKitAnchorManager _instance;

        //public static HoloKitAnchorManager Instance { get { return _instance; } }

        //public List<GameObject> m_ModelList;

        //private Transform arCamera;

        //[HideInInspector]
        //// The position of the peer hand transfered through the network.
        //public Vector3 m_PeerHandPosition = Vector3.zero;

        //[HideInInspector]
        //public bool m_IsPeerHandTracked = false;

        //private bool m_DoesInstantiate = false;

        //[HideInInspector]
        //public int m_ModelIndex = 0;

        //[HideInInspector]
        //public Vector3 m_ModelPosition;

        //[HideInInspector]
        //public Quaternion m_ModelRotation;

        //public bool m_IsHost = true;

        //private ARAnchorManager m_AnchorManager;

        //private List<GameObject> m_SceneModels = new List<GameObject>();

        //[DllImport("__Internal")]
        //public static extern void UnityHoloKit_AddNativeAnchor(int anchorId, float[] position, float[] rotation);

        //delegate void AnchorCallbackFunction(int val, float positionX, float positionY, float positionZ,
        //    float rotationX, float rotationY, float rotationZ, float rotationW);

        //[AOT.MonoPInvokeCallback(typeof(AnchorCallbackFunction))]
        //static void OnAnchorAdded(int val, float positionX, float positionY, float positionZ,
        //    float rotationX, float rotationY, float rotationZ, float rotationW)
        //{
        //    Debug.Log($"[HoloKitAnchorManager]: OnAnchorRevoked() receiving anchor name {val}");
        //    //Debug.Log($"[HoloKitAnchorManager]: anchor position ({positionX}, {positionY}, {positionZ})");
        //    //Debug.Log($"[HoloKitAnchorManager]: anchor rotation ({rotationX}, {rotationY}, {rotationZ}, {rotationW})");
        //    if (val == -1)
        //    {
        //        Debug.Log("[HoloKitAnchorManager]: receive an origin resetting anchor.");
        //        Vector3 newOriginPosition = new Vector3(positionX, positionY, positionZ);
        //        Quaternion newOriginRotation = new Quaternion(rotationX, rotationY, rotationZ, rotationW);
        //        Debug.Log($"[HoloKitAnchorManager]: anchor position in old coordinate system {newOriginPosition}");
        //        Debug.Log($"[HoloKitAnchorManager]: anchor rotation in old coordinate system {newOriginRotation}");
        //        //for (int i = 0; i < HoloKitAnchorManager.Instance.m_SceneModels.Count; i++)
        //        //{
        //        //    HoloKitAnchorManager.Instance.m_SceneModels[i].transform.position += newOriginPosition;
        //        //    HoloKitAnchorManager.Instance.m_SceneModels[i].transform.rotation *= newOriginRotation;
        //        //}
        //        return;
        //    }

        //    HoloKitAnchorManager.Instance.m_ModelIndex = val;
        //    HoloKitAnchorManager.Instance.m_ModelPosition = new Vector3(positionX, positionY, positionZ);
        //    HoloKitAnchorManager.Instance.m_ModelRotation = new Quaternion(rotationX, rotationY, rotationZ, rotationW);
        //    HoloKitAnchorManager.Instance.m_DoesInstantiate = true;
        //    //newModel.AddComponent<ARAnchor>();
        //}

        //[DllImport("__Internal")]
        //private static extern void UnityHoloKit_SetAnchorAddedDelegate(AnchorCallbackFunction callback);

        //delegate void UpdatePeerHandPosition(float x, float y, float z);

        //[AOT.MonoPInvokeCallback(typeof(UpdatePeerHandPosition))]
        //static void OnPeerHandPositionUpdated(float x, float y, float z)
        //{
        //    if (x == -101f && y == -101f && z == -101f)
        //    {
        //        HoloKitAnchorManager.Instance.m_IsPeerHandTracked = false;
        //        // TODO: the host's hand lost tracking, disable the local hand.
        //        return;
        //    }
        //    Debug.Log($"[HoloKitAnchorManager]: received peer hand position ({x}, {y}, {z}).");
        //    HoloKitAnchorManager.Instance.m_IsPeerHandTracked = true;
        //    HoloKitAnchorManager.Instance.m_PeerHandPosition = new Vector3(x, y, -z);
        //    //Debug.Log($"[HoloKitAnchorManager]: peer hand position is {HoloKitAnchorManager.Instance.m_PeerHandPosition}");
        //}

        //[DllImport("__Internal")]
        //private static extern void UnityHoloKit_SetUpdatePeerHandPositionDelegate(UpdatePeerHandPosition callback);

        //delegate void CollaborationSynchronized();

        //[AOT.MonoPInvokeCallback(typeof(CollaborationSynchronized))]
        //static void OnCollaborationSynchronized()
        //{
        //    Debug.Log("[HoloKitAnchorManager]: OnCollaborationSynchronized()");
        //    if (HoloKitAnchorManager.Instance.m_IsHost == true)
        //    {
        //        // Add an anchor which is at the coordinate origin.
        //        // This anchor will be used by other peers to reset their coordinate origin.
        //        float[] originPosition = { 0f, 0f, 0f };
        //        float[] originRotation = { 0f, 0f, 0f, 1f };
        //        // -1 is a special index, which indicates the origin anchor.
        //        UnityHoloKit_AddNativeAnchor(-1, originPosition, originRotation);
        //        return;
        //    }
        //    // Visual notification
        //}

        //[DllImport("__Internal")]
        //private static extern void UnityHoloKit_SetCollaborationSynchronizedDelegate(CollaborationSynchronized callback);

        //[DllImport("__Internal")]
        //private static extern void UnityHoloKit_SetIsCollaborationHost(bool val);

        //private void Awake()
        //{
        //    if (_instance != null && _instance != this)
        //    {
        //        Destroy(this.gameObject);
        //    }
        //    else
        //    {
        //        _instance = this;
        //    }
        //}

        //public void AddAnchor(int anchorNameIndex, Vector3 position, Quaternion rotation)
        //{
        //    float[] positionArray = { position.x, position.y, position.z };
        //    float[] rotationArray = { rotation.x, rotation.y, rotation.z, rotation.w };

        //    if (anchorNameIndex < m_ModelList.Count)
        //    {
        //        UnityHoloKit_AddNativeAnchor(anchorNameIndex, positionArray, rotationArray);
        //    }
        //    else
        //    {
        //        Debug.Log("[HoloKitAnchorManager]: invalid anchor name index.");
        //    }
        //}

        //void Start()
        //{
        //    UnityHoloKit_SetIsCollaborationHost(m_IsHost);
        //    arCamera = Camera.main.transform;
        //    UnityHoloKit_SetAnchorAddedDelegate(OnAnchorAdded);
        //    UnityHoloKit_SetUpdatePeerHandPositionDelegate(OnPeerHandPositionUpdated);
        //    UnityHoloKit_SetCollaborationSynchronizedDelegate(OnCollaborationSynchronized);
        //}

        //private void Update()
        //{
        //    if (m_DoesInstantiate)
        //    {
        //        Debug.Log("[HoloKitAnchorManager]: instantiating a new model.");
        //        GameObject newModel = Instantiate(m_ModelList[m_ModelIndex]) as GameObject;
        //        newModel.transform.position = m_ModelPosition;
        //        newModel.transform.rotation = m_ModelRotation;
        //        Debug.Log($"[HoloKitAnchorManager]: before reset origin {m_ModelPosition}, {m_ModelRotation}");
        //        newModel.AddComponent<ARAnchor>();

        //        m_SceneModels.Add(newModel);
        //        m_DoesInstantiate = false;
        //    }
        //}
    }
}