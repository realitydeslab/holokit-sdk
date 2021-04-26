using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using UnityEngine.XR.ARSubsystems;

public class HandTracking : MonoBehaviour
{
    private List<InputDevice> handDevices = new List<InputDevice>();
    private List<GameObject[]> handLandmarks = new List<GameObject[]>();

    public static bool landmarksInvisible = false;

    void Start()
    {
        var devices = new List<InputDevice>();
        // Get left hand device
        var desiredCharacteristics = InputDeviceCharacteristics.Left | InputDeviceCharacteristics.HandTracking |
             InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
             InputDeviceCharacteristics.TrackedDevice;
        InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
        foreach(var device in devices)
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
        handLandmarks.Add(GameObject.FindGameObjectsWithTag("LandmarkLeft"));
        handLandmarks.Add(GameObject.FindGameObjectsWithTag("LandmarkRight"));

        // TODO: color the landmarks
        for (int i = 0; i < 2; i++)
        {
            for (int j = 0; j < 21; j++)
            {
                handLandmarks[i][j].GetComponent<Renderer>().enabled = !landmarksInvisible;
                if (landmarksInvisible)
                {
                    continue;
                }
                if (j == 0)
                {
                    handLandmarks[i][j].GetComponent<Renderer>().material.color = Color.gray;
                }
                if (j == 1 || j == 5 || j == 9 || j == 13 || j == 17)
                {
                    handLandmarks[i][j].GetComponent<Renderer>().material.color = Color.red;
                }
                if (j == 2 || j == 6 || j == 10 || j == 14 || j == 18)
                {
                    handLandmarks[i][j].GetComponent<Renderer>().material.color = Color.green;
                }
                if (j == 3 || j == 7 || j == 11 || j == 15 || j == 19)
                {
                    handLandmarks[i][j].GetComponent<Renderer>().material.color = Color.blue;
                }
                if (j == 4 || j == 8 || j == 12 || j == 16 || j == 20)
                {
                    handLandmarks[i][j].GetComponent<Renderer>().material.color = Color.cyan;
                }
            }
        }
    }

    void FixedUpdate()
    {
        UpdateHandLandmarks();
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
                                    handLandmarks[handIndex][landmarkIndex].SetActive(true);
                                    handLandmarks[handIndex][landmarkIndex++].transform.position = position;
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
                                            handLandmarks[handIndex][landmarkIndex].SetActive(true);
                                            handLandmarks[handIndex][landmarkIndex++].transform.position = position;
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
                            handLandmarks[handIndex][i].SetActive(false);
                        }
                    }
                }
            }
        }
    }
}
