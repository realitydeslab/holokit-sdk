using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using UnityEngine.XR.ARSubsystems;

namespace UnityEngine.XR.HoloKit
{
    public class HandTracking : MonoBehaviour
    {
        private List<InputDevice> handDevices = new List<InputDevice>();
        private List<GameObject[]> multiHandLandmakrs = new List<GameObject[]>();

        public static bool landmarksInvisible = false;

        private HoloKitHandGesture currentGesture = HoloKitHandGesture.None;

        [SerializeField]
        private GameObject prefab;

        void Start()
        {
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
            multiHandLandmakrs.Add(GameObject.FindGameObjectsWithTag("LandmarkLeft"));
            multiHandLandmakrs.Add(GameObject.FindGameObjectsWithTag("LandmarkRight"));

            // Color the landmarks
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < 21; j++)
                {
                    multiHandLandmakrs[i][j].GetComponent<Renderer>().enabled = !landmarksInvisible;
                    if (landmarksInvisible)
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
        }

        void FixedUpdate()
        {
            UpdateHandLandmarks();
            /*
            HoloKitHandGesture tempGesture = GetCurrentGesture(multiHandLandmakrs[0]);
            if (currentGesture == HoloKitHandGesture.Fist && tempGesture == HoloKitHandGesture.None)
            {
                Debug.Log("Create anchor.");
                if (multiHandLandmakrs[0][0] != null)
                {
                    Quaternion rotation = new Quaternion(0.0f, 0.0f, 0.0f, 1.0f);
                    var gameObject = Instantiate(prefab, multiHandLandmakrs[0][0].transform.position, rotation);
                    ARAnchor anchor;
                    anchor = gameObject.GetComponent<ARAnchor>();
                    if (anchor == null)
                    {
                        anchor = gameObject.AddComponent<ARAnchor>();
                    }
                }
                else
                {
                    Debug.Log("null");
                }
            }
            currentGesture = tempGesture;
            */
            //Debug.Log("Right hand");
            //GetCurrentGesture(multiHandLandmakrs[1]);
            
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
                                        multiHandLandmakrs[handIndex][landmarkIndex].SetActive(true);
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
                                                multiHandLandmakrs[handIndex][landmarkIndex].SetActive(true);
                                                multiHandLandmakrs[handIndex][landmarkIndex++].transform.position = position;
                                            }
                                            fingerBoneIndex++;
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            //Debug.Log("Left hand is not tracked.");
                            for (int i = 0; i < 21; i++)
                            {
                                multiHandLandmakrs[handIndex][i].SetActive(false);
                            }
                        }
                    }
                }
            }
        }

        HoloKitHandGesture GetCurrentGesture(GameObject[] handLandmarks)
        {
            float thumbDist = Vector3.Distance(handLandmarks[(int)HoloKitHandLandmark.ThumbStart].transform.position, handLandmarks[(int)HoloKitHandLandmark.Thumb2].transform.position);
            float indexDist = Vector3.Distance(handLandmarks[(int)HoloKitHandLandmark.IndexStart].transform.position, handLandmarks[(int)HoloKitHandLandmark.Index2].transform.position);
            float middleDist = Vector3.Distance(handLandmarks[(int)HoloKitHandLandmark.MiddleStart].transform.position, handLandmarks[(int)HoloKitHandLandmark.Middle2].transform.position);
            float ringDist = Vector3.Distance(handLandmarks[(int)HoloKitHandLandmark.RingStart].transform.position, handLandmarks[(int)HoloKitHandLandmark.Ring2].transform.position);
            float pinkyDist = Vector3.Distance(handLandmarks[(int)HoloKitHandLandmark.PinkyStart].transform.position, handLandmarks[(int)HoloKitHandLandmark.Pinky2].transform.position);

            //Debug.Log($"thumb dist: {thumbDist}");
            //Debug.Log($"index dist: {indexDist}");
            //Debug.Log($"middle dist: {middleDist}");
            //Debug.Log($"ring dist: {ringDist}");
            //Debug.Log($"pinky dist: {pinkyDist}");

            float maxDist = 0.033f;
            float minDist = 0.0001f;
            if(indexDist < maxDist && middleDist < maxDist && ringDist < maxDist && pinkyDist < maxDist &&
                indexDist > minDist && middleDist > minDist && ringDist > minDist && pinkyDist > minDist)
            {
                //Debug.Log("Fist");
                return HoloKitHandGesture.Fist;
            } else
            {
                //Debug.Log("None");
                return HoloKitHandGesture.None;
            }

            return HoloKitHandGesture.None;
        }

    }
}