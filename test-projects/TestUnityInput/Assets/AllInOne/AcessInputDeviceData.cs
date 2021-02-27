using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class AcessInputDeviceData : MonoBehaviour
{

    private InputDevice HoloKitHMD = new InputDevice();
    private InputDevice HoloKitHand = new InputDevice();

    // Start is called before the first frame update
    void Start()
    {
        // 1. get all input devices
        Debug.Log("<<<<<<<<<< trying to get all input devices:");
        var inputDevices = new List<InputDevice>();
        InputDevices.GetDevices(inputDevices);
        foreach (var device in inputDevices)
        {
            //Debug.Log(string.Format("Device found with name '{0}' and role '{1}'", device.name, device.role.ToString()));
        }

        // 2. get devices by characteristics
        Debug.Log("<<<<<<<<<< trying to get devices by characteristics");
        // get HoloKitHMD
        var HoloKitHMDs = new List<InputDevice>();
        var desiredCharacteristics = InputDeviceCharacteristics.HeadMounted | InputDeviceCharacteristics.TrackedDevice;
        InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, HoloKitHMDs);
        foreach (var device in HoloKitHMDs)
        {
            HoloKitHMD = device;
            Debug.Log(string.Format("Device name '{0}' has characteristics '{1}'", device.name, device.characteristics.ToString()));
        }
        // get right hand
        var HoloKitHands = new List<InputDevice>();
        desiredCharacteristics = InputDeviceCharacteristics.Right | InputDeviceCharacteristics.HandTracking |
            InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.HeldInHand |
            InputDeviceCharacteristics.TrackedDevice;
        InputDevices.GetDevicesWithCharacteristics(desiredCharacteristics, HoloKitHands);
        foreach (var device in HoloKitHands)
        {
            HoloKitHand = device;
            Debug.Log(string.Format("Device name '{0}' has characteristics '{1}'", device.name, device.characteristics.ToString()));
        }
    }

    // Update is called once per frame
    void Update()
    {


        InputDevice holokitHand = InputDevices.GetDeviceAtXRNode(XRNode.RightHand);
        if (holokitHand != null)
        {
            //
            // holokitHand.TryGetFeatureUsages()
            // Debug.Log($"{holokitHand.name}");

        }

        // get values from HoloKitHMD:
        Debug.Log("<<<<<<<<<< HoloKitHMD device values:");
        if (HoloKitHMD.isValid)
        {
            Vector3 centerEyePosition;
            if (HoloKitHMD.TryGetFeatureValue(CommonUsages.centerEyePosition, out centerEyePosition))
            {
                Debug.Log(string.Format(" centerEyePosition is: [{0}, {1}, {2}]", centerEyePosition.x, centerEyePosition.y, centerEyePosition.z));
            }
            Quaternion centerEyeRotation;
            if (HoloKitHMD.TryGetFeatureValue(CommonUsages.centerEyeRotation, out centerEyeRotation))
            {
                Debug.Log(string.Format(" centerEyeRotation is: [{0}, {1}, {2}]", centerEyeRotation.x, centerEyeRotation.y, centerEyeRotation.z));
            }
        }

        // get bone values from HoloKitHand
        Debug.Log("<<<<<<<<<< HoloKitHand device values:");
        if (HoloKitHand.isValid)
        {

            
            var inputFeatureUsages = new List<InputFeatureUsage>();
            if (HoloKitHand.TryGetFeatureUsages(inputFeatureUsages))
            {
                foreach (var inputFeatureUsage in inputFeatureUsages)
                {
         
                    if (inputFeatureUsage.type == typeof(Hand))
                    {
                        Debug.Log("Got hand");
             
                        Hand hand;
                        if(HoloKitHand.TryGetFeatureValue(inputFeatureUsage.As<Hand>(), out hand))
                        {
                            Debug.Log("Got value");
                            Bone bone;
                            if(hand.TryGetRootBone(out bone))
                            {
                                Debug.Log("Got root bone !!!");
                                Vector3 position;
                                if(bone.TryGetPosition(out position))
                                {
                                    Debug.Log(position);
                                }
                            }
                            List<Bone> fingerBones = new List<Bone>();
                            if(hand.TryGetFingerBones(HandFinger.Thumb, fingerBones))
                            {
                                Debug.Log("Got thumb finger bones !!!");
                                Vector3 position;
                                foreach(var fingerBone in fingerBones)
                                {
                                    if(fingerBone.TryGetPosition(out position))
                                    {
                                        Debug.Log(position);
                                    }
                                }
                            }
                        }
               
                    }
                    //else if (inputFeatureUsage.type == typeof(Bone))
                    //{
                    //    Debug.Log($"Got bone {inputFeatureUsage.ToString()}");
                        

                    //    Bone bone;
                    //    // the problem is that we always get the first bone
                    //    HoloKitHand.TryGetFeatureValue(inputFeatureUsage.As<Bone>(), out bone);
                    //    Vector3 position;
                    //    if (bone.TryGetPosition(out position))
                    //    {
                            
                    //        Debug.Log(position);
                    //    }
                    //}
                }


                /*
                Hand hand;
                if (HoloKitHand.TryGetFeatureValue(CommonUsages.handData, out hand))
                {
                    Debug.Log("got hand");
                    List<Bone> bones = new List<Bone>();
                    bool hasThumb = hand.TryGetFingerBones(HandFinger.Thumb, bones);
                    Debug.Log($"has thumb {hasThumb}");
                    foreach (Bone bone in bones)
                    {
                        Vector3 position;
                        bone.TryGetPosition(out position);
                        Debug.Log(position);
                    }
                    //Bone bone;
                    //if(hand.TryGetRootBone(out bone))
                    //{
                    //    Debug.Log("got bone");
                    //}
                }
                */
            }
        }
    }
}