using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitAnchorManager : MonoBehaviour
    {

        private static HoloKitAnchorManager _instance;

        public static HoloKitAnchorManager Instance { get { return _instance; } }

        public List<GameObject> modelList;

        private Transform arCamera;

        private int m_ModelCount = 0;

        private Vector3 offset = new Vector3(0f, 0f, 0.7f);

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_AddNativeAnchor(int anchorId, float[] position, float[] rotation);

        [DllImport("__Internal")]
        private static extern void UnityHolokit_SetAnchorRevoke(AnchorCallbackFunction callback);

        delegate void AnchorCallbackFunction(int val, float positionX, float positionY, float positionZ,
            float rotationX, float rotationY, float rotationZ, float rotationW);

        [AOT.MonoPInvokeCallback(typeof(AnchorCallbackFunction))]
        static void OnAnchorRevoked(int val, float positionX, float positionY, float positionZ,
            float rotationX, float rotationY, float rotationZ, float rotationW)
        {
            Debug.Log($"[HoloKitAnchorManager]: OnAnchorRevoked() with value {val}");
            Debug.Log($"[HoloKitAnchorManager]: anchor position ({positionX}, {positionY}, {positionZ})");
            Debug.Log($"[HoloKitAnchorManager]: anchor rotation ({rotationX}, {rotationY}, {rotationZ}, {rotationW})");

            GameObject model = HoloKitAnchorManager.Instance.modelList[0];
            switch (val)
            {
                case 0:
                    model = HoloKitAnchorManager.Instance.modelList[0];
                    break;
                case 1:
                    model = HoloKitAnchorManager.Instance.modelList[1];
                    break;
                case 2:
                    model = HoloKitAnchorManager.Instance.modelList[2];
                    break;
                default:
                    break;
            }
            GameObject newModel = Instantiate(model) as GameObject;
            newModel.transform.position = new Vector3(positionX, positionY, positionZ);
            newModel.transform.rotation = new Quaternion(rotationX, rotationY, rotationZ, rotationW);
            newModel.AddComponent<ARAnchor>();
        }

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
            HandTrackingManager.OnChangedToBloom += AddAnchor;
        }

        private void OnDisable()
        {
            HandTrackingManager.OnChangedToBloom -= AddAnchor;
        }

        private void AddAnchor()
        {
            Vector3 position = arCamera.position + arCamera.TransformVector(offset);
            Quaternion rotation = arCamera.rotation;

            float[] positionArray = { position.x, position.y, position.z };
            float[] rotationArray = { rotation.x, rotation.y, rotation.z, rotation.w };

            UnityHoloKit_AddNativeAnchor(m_ModelCount++, positionArray, rotationArray);
            if (m_ModelCount == 3)
            {
                m_ModelCount = 0;
            }
        }

        void Start()
        {
            arCamera = Camera.main.transform;
            UnityHolokit_SetAnchorRevoke(OnAnchorRevoked);
        }

        void Update()
        {

        }
    }
}