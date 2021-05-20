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

        private List<InputDevice> handDevices = new List<InputDevice>();
        private List<GameObject[]> multiHandLandmakrs = new List<GameObject[]>();

        private List<HoloKitHandGesture> currentHandGestures = new List<HoloKitHandGesture>();

        private int currentGestureInterval = 0;

        private const int kMinGestureInterval = 3;

        private AROcclusionManager occlusionManager;

        private List<GameObject> holoKitHands = new List<GameObject>();

        [SerializeField] private bool handTrackingEnabled = true;

        [SerializeField] private bool landmarksVisible = true;

        [SerializeField] private bool colliderEnabled = true;

        [DllImport("__Internal")]
        public static extern bool UnityHoloKit_EnableHandTracking(bool enabled);

        public delegate void BloomEvent();
        public static event BloomEvent OnChangedToBloom;

        public delegate void NoneEvent();
        public static event NoneEvent OnChangedToNone;

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

        void Start()
        {
            occlusionManager = GameObject.Find("HoloKitCamera").GetComponent<AROcclusionManager>();
            holoKitHands.Add(transform.GetChild(0).GetChild(0).gameObject);
            holoKitHands.Add(transform.GetChild(0).GetChild(1).gameObject);

            var devices = new List<InputDevice>();
            // Get left hand device
            var desiredCharacteristics = InputDeviceCharacteristics.Left | InputDeviceCharacteristics.HandTracking |
                 InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
                 InputDeviceCharacteristics.TrackedDevice;
            InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
            foreach (var device in devices)
            {
                handDevices.Add(device);
                //Debug.Log("HoloKit left hand connected.");
            }

            // Get right hand device
            desiredCharacteristics = InputDeviceCharacteristics.Right | InputDeviceCharacteristics.HandTracking |
                 InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
                 InputDeviceCharacteristics.TrackedDevice;
            InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
            foreach (var device in devices)
            {
                handDevices.Add(device);
                //Debug.Log("HoloKit right hand connected.");
            }

            // Get hand landmarks using the tag
            GameObject[] leftLandmarks = GameObject.FindGameObjectsWithTag("LandmarkLeft");
            GameObject[] rightLandmarks = GameObject.FindGameObjectsWithTag("LandmarkRight");
            System.Array.Reverse(leftLandmarks);
            System.Array.Reverse(rightLandmarks);
            multiHandLandmakrs.Add(leftLandmarks);
            multiHandLandmakrs.Add(rightLandmarks);

            // Color the landmarks
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < 21; j++)
                {
                    multiHandLandmakrs[i][j].GetComponent<Renderer>().enabled = landmarksVisible;
                    if (!landmarksVisible)
                    {
                        continue;
                    }
                    if (j == 0)
                    {
                        multiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.gray;
                    }
                    if (j == 1 || j == 5 || j == 9 || j == 13 || j == 17)
                    {
                        multiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.red;
                    }
                    if (j == 2 || j == 6 || j == 10 || j == 14 || j == 18)
                    {
                        multiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.green;
                    }
                    if (j == 3 || j == 7 || j == 11 || j == 15 || j == 19)
                    {
                        multiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.blue;
                    }
                    if (j == 4 || j == 8 || j == 12 || j == 16 || j == 20)
                    {
                        multiHandLandmakrs[i][j].GetComponent<Renderer>().material.color = Color.cyan;
                    }
                }
            }

            if (!colliderEnabled)
            {
                DisableCollider();
            }

            currentHandGestures.Add(HoloKitHandGesture.None);
            currentHandGestures.Add(HoloKitHandGesture.None);

            if (handTrackingEnabled)
            {
                EnableHandTracking();
            }
            else
            {
                DisableHandTracking();
            }
        }

        void FixedUpdate()
        {
            if(handTrackingEnabled)
            {
                UpdateHandLandmarks();
            }
        }

        void UpdateHandLandmarks()
        {
            for (int handIndex = 0; handIndex < 2; handIndex++)
            {
                if (handDevices[handIndex].isValid)
                {
                    // check if left hand is currently tracked
                    bool isTracked;
                    if (handDevices[handIndex].TryGetFeatureValue(CommonUsages.isTracked, out isTracked))
                    {
                        if (isTracked)
                        {
                            if (!holoKitHands[handIndex].activeSelf)
                            {
                                holoKitHands[handIndex].SetActive(true);
                            }
                            int landmarkIndex = 0;
                            Hand hand;
                            if (handDevices[handIndex].TryGetFeatureValue(CommonUsages.handData, out hand))
                            {
                                // Get root bone
                                Bone bone;
                                if (hand.TryGetRootBone(out bone))
                                {
                                    Vector3 position;
                                    if (bone.TryGetPosition(out position))
                                    {
                                        position.z = -position.z;
                                        multiHandLandmakrs[handIndex][landmarkIndex++].transform.position = position;
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
                                                multiHandLandmakrs[handIndex][landmarkIndex++].transform.position = position;
                                            }
                                            fingerBoneIndex++;
                                        }
                                    }
                                }
                            }
                            // Recognize current hand gesture
                            bool primaryButtonValue;
                            if (handDevices[handIndex].TryGetFeatureValue(CommonUsages.primaryButton, out primaryButtonValue))
                            {
                                if (primaryButtonValue && currentHandGestures[handIndex] == HoloKitHandGesture.None && currentGestureInterval > kMinGestureInterval)
                                {
                                    currentHandGestures[handIndex] = HoloKitHandGesture.Bloom;
                                    currentGestureInterval = 0;
                                    // TODO: send a Unity event
                                    Debug.Log("[HandTracking]: current gesture changed to BLOOM.");
                                    OnChangedToBloom();
                                }
                                else if (!primaryButtonValue && currentHandGestures[handIndex] == HoloKitHandGesture.Bloom && currentGestureInterval > kMinGestureInterval)
                                {
                                    currentHandGestures[handIndex] = HoloKitHandGesture.None;
                                    currentGestureInterval = 0;
                                    // TODO: send a Unity event
                                    Debug.Log("[HandTracking]: current gesture changed to NONE.");
                                    OnChangedToNone();
                                }
                                else
                                {
                                    currentGestureInterval++;
                                }
                            }
                        }
                        else
                        {
                            // When hand tracking is lost
                            if (holoKitHands[handIndex].activeSelf)
                            {
                                ResetPosition();
                                holoKitHands[handIndex].SetActive(false);
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
                GameObject[] handLandmarks = multiHandLandmakrs[i];
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
                GameObject[] handLandmarks = multiHandLandmakrs[i];
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
            occlusionManager.requestedEnvironmentDepthMode = ARSubsystems.EnvironmentDepthMode.Best;
            transform.GetChild(0).transform.gameObject.SetActive(true);
            handTrackingEnabled = true;
            Debug.Log("[HandTrackingManager]: hand tracking enabled.");
        }

        public void DisableHandTracking()
        {
            UnityHoloKit_EnableHandTracking(false);
            occlusionManager.requestedEnvironmentDepthMode = ARSubsystems.EnvironmentDepthMode.Disabled;
            ResetPosition();
            transform.GetChild(0).transform.gameObject.SetActive(false);
            handTrackingEnabled = false;
            Debug.Log("[HandTrackingManager]: hand tracking disabled.");
        }
    }
}