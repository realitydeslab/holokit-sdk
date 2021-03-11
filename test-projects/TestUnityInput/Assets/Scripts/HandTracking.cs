using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;
using UnityEngine.XR.ARSubsystems;

public class HandTracking : MonoBehaviour
{

    private InputDevice HoloKitLeftHand = new InputDevice();
    private InputDevice HoloKitRightHand = new InputDevice();
    private GameObject[] leftHandLandmarks;
    private GameObject[] rightHandLandmarks;

    private ARSessionOrigin sessionOrigin;
    private ARSession session;
    private int frameCount = 0;

    public AROcclusionManager occlusionManager
    {
        get => m_OcclusionManager;
        set => m_OcclusionManager = value;
    }

    [SerializeField]
    [Tooltip("The AROcclusionManager which will produce depth textures.")]
    AROcclusionManager m_OcclusionManager;


    void Start()
    {

        // get ar session
        session = FindObjectOfType<ARSession>();
        if(session)
        {
            Debug.Log("Successfully got the reference of the ar session.");
            
        }
            
        sessionOrigin = FindObjectOfType<ARSessionOrigin>();
        if(sessionOrigin)
        {
            Debug.Log("Successfully got the reference of the ar session origin.");
            
        } 

        var devices = new List<InputDevice>();
        // try get left hand
        var desiredCharacteristics = InputDeviceCharacteristics.Left | InputDeviceCharacteristics.HandTracking |
             InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
             InputDeviceCharacteristics.TrackedDevice;
        InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
        foreach(var device in devices)
        {
            HoloKitLeftHand = device;
            Debug.Log("HoloKit left hand connected.");
        }

        // try get right hand
        desiredCharacteristics = InputDeviceCharacteristics.Right | InputDeviceCharacteristics.HandTracking |
             InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
             InputDeviceCharacteristics.TrackedDevice;
        InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, devices);
        foreach (var device in devices)
        {
            HoloKitRightHand = device;
            Debug.Log("HoloKit right hand connected.");
        }

        // try get left hand landmarks
        leftHandLandmarks = GameObject.FindGameObjectsWithTag("LandmarkLeft");
        if(leftHandLandmarks.Length == 21)
        {
            Debug.Log("Left hand landmarks got.");
        }
        // try get right hand landmarks
        rightHandLandmarks = GameObject.FindGameObjectsWithTag("LandmarkRight");
        if(rightHandLandmarks.Length == 21)
        {
            Debug.Log("Right hand landmarks got.");
        }


        // Enable depth detection
        Debug.Assert(occlusionManager != null, "no occlusion manager");
        var descriptor = occlusionManager.descriptor;
        Debug.Assert(descriptor != null, "no descriptor");
    }

    void FixedUpdate()
    {
        frameCount++;
        // update left hand landmarks
        if(HoloKitLeftHand.isValid)
        {
            // check if left hand is currently tracked
            bool isTracked;
            if (HoloKitLeftHand.TryGetFeatureValue(CommonUsages.isTracked, out isTracked))
            {
                if (isTracked)
                {
                    int landmarkIndex = 0;
                    Hand hand;
                    if (HoloKitLeftHand.TryGetFeatureValue(CommonUsages.handData, out hand))
                    {
                        // try get root bone
                        Bone bone;
                        if (hand.TryGetRootBone(out bone))
                        {
                            Vector3 position;
                            if (bone.TryGetPosition(out position))
                            {
                                position.z = -position.z;
                                leftHandLandmarks[landmarkIndex].SetActive(true);
                                leftHandLandmarks[landmarkIndex++].transform.position = position;
                            }
                        }
                        else
                        {
                            Debug.Log("Failed to get root bone.");
                        }
                        // try get finger bones
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
                                        leftHandLandmarks[landmarkIndex].SetActive(true);
                                        leftHandLandmarks[landmarkIndex++].transform.position = position;
                                    }
                                    fingerBoneIndex++;
                                }
                            }
                        }
                    }
                }
                else
                {
                    Debug.Log("Left hand is not tracked.");
                    for(int i = 0; i < 21; i++)
                    {
                        leftHandLandmarks[i].SetActive(false);
                    }
                }
            }
 
        }



        // update right hand landmarks
        if (HoloKitRightHand.isValid)
        {
            bool isTracked;
            if(HoloKitRightHand.TryGetFeatureValue(CommonUsages.isTracked, out isTracked))
            {
                if (isTracked)
                {
                    int landmarkIndex = 0;
                    Hand hand;
                    if (HoloKitRightHand.TryGetFeatureValue(CommonUsages.handData, out hand))
                    {
                        // try get root bone
                        Bone bone;
                        if (hand.TryGetRootBone(out bone))
                        {
                            Vector3 position;
                            if (bone.TryGetPosition(out position))
                            {
                                position.z = -position.z;
                                rightHandLandmarks[landmarkIndex].SetActive(true);
                                rightHandLandmarks[landmarkIndex++].transform.position = position;
                            }
                        }
                        // try get finger bones
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
                                        rightHandLandmarks[landmarkIndex].SetActive(true);
                                        rightHandLandmarks[landmarkIndex++].transform.position = position;
                                    }
                                    fingerBoneIndex++;
                                }
                            }
                        }
                    }
                }
                else
                {
                    Debug.Log("Right hand is not tracked");
                    for (int i = 0; i < 21; i++)
                    {
                        rightHandLandmarks[i].SetActive(false);
                    }
                }
            }
        }
    }
}
