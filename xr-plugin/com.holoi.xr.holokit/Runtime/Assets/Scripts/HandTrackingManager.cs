using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class HandTrackingManager : MonoBehaviour
    {
        private static HandTrackingManager _instance;

        public static HandTrackingManager Instance { get { return _instance; } }

        private List<InputDevice> m_HandDevices = new List<InputDevice>();

        private List<GameObject[]> m_MultiHandLandmakrs = new List<GameObject[]>();

        private int m_CurrentGestureInterval = 0;

        private AROcclusionManager m_OcclusionManager;

        private List<GameObject> m_HoloKitHands = new List<GameObject>();

        [SerializeField] private bool m_HandTrackingEnabled = true;

        [SerializeField] private bool m_LandmarksVisibilityEnabled = true;

        [SerializeField] private bool m_ColliderEnabled = true;

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_EnableHandTracking(bool val);

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

        private void Start()
        {
            m_OcclusionManager = GameObject.Find("HoloKitCamera").GetComponent<AROcclusionManager>();
            m_HoloKitHands.Add(transform.GetChild(0).GetChild(0).gameObject);
            m_HoloKitHands.Add(transform.GetChild(0).GetChild(1).gameObject);

            var devices = new List<InputDevice>();
            // Get left hand device
            var desiredCharacteristics = InputDeviceCharacteristics.Left | InputDeviceCharacteristics.HandTracking |
                 InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
                 InputDeviceCharacteristics.TrackedDevice;
            InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
            foreach (var device in devices)
            {
                m_HandDevices.Add(device);
                //Debug.Log("HoloKit left hand connected.");
            }

            // Get right hand device
            desiredCharacteristics = InputDeviceCharacteristics.Right | InputDeviceCharacteristics.HandTracking |
                 InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
                 InputDeviceCharacteristics.TrackedDevice;
            InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
            foreach (var device in devices)
            {
                m_HandDevices.Add(device);
                //Debug.Log("HoloKit right hand connected.");
            }

            // Get hand landmarks using the tag
            GameObject[] leftLandmarks = GameObject.FindGameObjectsWithTag("LandmarkLeft");
            GameObject[] rightLandmarks = GameObject.FindGameObjectsWithTag("LandmarkRight");
            System.Array.Reverse(leftLandmarks);
            System.Array.Reverse(rightLandmarks);
            m_MultiHandLandmakrs.Add(leftLandmarks);
            m_MultiHandLandmakrs.Add(rightLandmarks);

            // Color the landmarks
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < 21; j++)
                {
                    m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().enabled = m_LandmarksVisibilityEnabled;
                    if (!m_LandmarksVisibilityEnabled)
                    {
                        continue;
                    }
                    if (j == 0)
                    {
                        m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.gray;
                    }
                    if (j == 1 || j == 5 || j == 9 || j == 13 || j == 17)
                    {
                        m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.red;
                    }
                    if (j == 2 || j == 6 || j == 10 || j == 14 || j == 18)
                    {
                        m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.green;
                    }
                    if (j == 3 || j == 7 || j == 11 || j == 15 || j == 19)
                    {
                        m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.blue;
                    }
                    if (j == 4 || j == 8 || j == 12 || j == 16 || j == 20)
                    {
                        m_MultiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.cyan;
                    }
                }
            }

            if (!m_ColliderEnabled)
            {
                DisableCollider();
            }

            if (m_HandTrackingEnabled)
            {
                EnableHandTracking();
            }
            else
            {
                DisableHandTracking();
            }
        }

        private void Update()
        {
            if(m_HandTrackingEnabled)
            {
                UpdateHandLandmarks();
            }
        }

        void UpdateHandLandmarks()
        {
            for (int handIndex = 0; handIndex < 2; handIndex++)
            {
                if (m_HandDevices[handIndex].isValid)
                {
                    // check if left hand is currently tracked
                    bool isTracked;
                    if (m_HandDevices[handIndex].TryGetFeatureValue(CommonUsages.isTracked, out isTracked))
                    {
                        if (isTracked)
                        {
                            if (!m_HoloKitHands[handIndex].activeSelf)
                            {
                                m_HoloKitHands[handIndex].SetActive(true);
                            }
                            int landmarkIndex = 0;
                            Hand hand;
                            if (m_HandDevices[handIndex].TryGetFeatureValue(CommonUsages.handData, out hand))
                            {
                                // Get root bone
                                Bone bone;
                                if (hand.TryGetRootBone(out bone))
                                {
                                    Vector3 position;
                                    if (bone.TryGetPosition(out position))
                                    {
                                        position.z = -position.z;
                                        m_MultiHandLandmakrs[handIndex][landmarkIndex++].transform.position = position;
                                    }
                                }
                                // Get finger bones
                                for (int i = 0; i < 5; i++)
                                {
                                    List<Bone> fingerBones = new List<Bone>();
                                    if (hand.TryGetFingerBones(HandFinger.Thumb + i, fingerBones))
                                    {
                                        int fingerBoneIndex = 0;
                                        foreach (var fingerBone in fingerBones)
                                        {
                                            Vector3 position;
                                            if (fingerBone.TryGetPosition(out position))
                                            {
                                                position.z = -position.z;
                                                m_MultiHandLandmakrs[handIndex][landmarkIndex++].transform.position = position;
                                            }
                                            fingerBoneIndex++;
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            // When hand tracking is lost
                            if (m_HoloKitHands[handIndex].activeSelf)
                            {
                                m_HoloKitHands[handIndex].SetActive(false);
                            }
                        }
                    }
                }
            }
        }

        public void DisableCollider()
        {
            Debug.Log("[HandTracking]: DisableCollider()");
            for (int i = 0; i < 2; i++)
            {
                GameObject[] handLandmarks = m_MultiHandLandmakrs[i];
                for (int j = 0; j < 21; j++)
                {
                    GameObject handLandmark = handLandmarks[j];
                    handLandmark.GetComponent<BoxCollider>().enabled = false;
                }
            }
        }

        public void ResetPosition()
        {
            Debug.Log("[HandTracking]: ResetPosition()");
            for (int i = 0; i < 2; i++)
            {
                GameObject[] handLandmarks = m_MultiHandLandmakrs[i];
                for (int j = 0; j < 21; j++)
                {
                    GameObject handLandmark = handLandmarks[j];
                    handLandmark.transform.position = Vector3.zero;
                }
            }
        }

        public void EnableHandTracking()
        {
            UnityHoloKit_EnableHandTracking(true);
            //m_OcclusionManager.requestedEnvironmentDepthMode = ARSubsystems.EnvironmentDepthMode.Best;
            transform.GetChild(0).transform.gameObject.SetActive(true);
            m_HandTrackingEnabled = true;
            Debug.Log("[HandTrackingManager]: hand tracking enabled.");
        }

        public void DisableHandTracking()
        {
            UnityHoloKit_EnableHandTracking(false);
            //m_OcclusionManager.requestedEnvironmentDepthMode = ARSubsystems.EnvironmentDepthMode.Disabled;
            // Enable human segmentation hand tracking
            //m_OcclusionManager.requestedHumanDepthMode = ARSubsystems.HumanSegmentationDepthMode.Fastest;
            //m_OcclusionManager.requestedHumanStencilMode = ARSubsystems.HumanSegmentationStencilMode.Fastest;
            //m_OcclusionManager.requestedOcclusionPreferenceMode = ARSubsystems.OcclusionPreferenceMode.PreferHumanOcclusion;
            ResetPosition();
            transform.GetChild(0).transform.gameObject.SetActive(false);
            m_HandTrackingEnabled = false;
            Debug.Log("[HandTrackingManager]: hand tracking disabled.");
        }

        public bool GetHandTrackingEnabled()
        {
            return m_HandTrackingEnabled;
        }
    }
}