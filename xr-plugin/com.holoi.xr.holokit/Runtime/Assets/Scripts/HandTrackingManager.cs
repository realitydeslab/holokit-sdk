using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace UnityEngine.XR.HoloKit
{
    public class HandTrackingManager : MonoBehaviour
    {
        private static HandTrackingManager _instance;

        public static HandTrackingManager Instance { get { return _instance; } }

        private List<InputDevice> m_HandDevices = new List<InputDevice>();

        private List<GameObject[]> m_MultiHandLandmakrs = new List<GameObject[]>();

        private List<GameObject> m_HoloKitHands = new List<GameObject>();

        [SerializeField] private bool m_EnableHandTrackingOnStart = true;

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_TurnOnHandTracking();

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_TurnOffHandTracking();

        [DllImport("__Internal")]
        private static extern bool UnityHoloKit_IsHandTrackingOn();

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

            // Get hand landmarks
            GameObject[] leftLandmarks = new GameObject[21];
            GameObject[] rightLandmarks = new GameObject[21];
            for (int i = 0; i < transform.GetChild(0).GetChild(0).childCount; i++)
            {
                leftLandmarks[i] = transform.GetChild(0).GetChild(0).GetChild(i).gameObject;
                rightLandmarks[i] = transform.GetChild(0).GetChild(1).GetChild(i).gameObject;
            }
            
            System.Array.Reverse(leftLandmarks);
            System.Array.Reverse(rightLandmarks);
            m_MultiHandLandmakrs.Add(leftLandmarks);
            m_MultiHandLandmakrs.Add(rightLandmarks);

            // Color the landmarks
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < 21; j++)
                {
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

            if (m_EnableHandTrackingOnStart)
            {
                TurnOnHandTracking();
            }
        }

        private void Update()
        {
            if(UnityHoloKit_IsHandTrackingOn())
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

        public void TurnOnHandTracking()
        {
            HoloKitManager.Instance.StartHoloKitInputSubsystem();
            UnityHoloKit_TurnOnHandTracking();
        }

        public void TurnOffHandTracking()
        {
            UnityHoloKit_TurnOffHandTracking();
            HoloKitManager.Instance.StopHoloKitInputSubsystem();
        }

        public bool IsHandTrackingOn()
        {
            return UnityHoloKit_IsHandTrackingOn();
        }
    }
}