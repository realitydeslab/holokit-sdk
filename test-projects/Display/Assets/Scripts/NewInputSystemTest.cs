using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class NewInputSystemTest : MonoBehaviour
{

    private List<UnityEngine.XR.InputDevice> allDevices = new List<UnityEngine.XR.InputDevice>();

    private List<UnityEngine.XR.InputDevice> holoKitHands = new List<UnityEngine.XR.InputDevice>();

    private const string kHoloKitLeftHandName = "HoloKit Left Hand";

    private const string kHoloKitRightHandName = "HoloKit Right Hand";

    void Start()
    {
        UnityEngine.XR.InputDevices.GetDevices(allDevices);
        Debug.Log($"[NewInputSystemTest]: current number of XR input devices: {allDevices.Count}");
        Debug.Log($"[NewInputSystemTest]: their names are: {allDevices[0].name}, {allDevices[1].name}, {allDevices[2].name} and {allDevices[3].name}");
        Debug.Log($"[NewInputSystemTest]: their roles are: {allDevices[0].role}, {allDevices[1].role}, {allDevices[2].role} and {allDevices[3].role}");

        holoKitHands.Add(new InputDevice());
        holoKitHands.Add(new InputDevice());
        for (int i = 0; i < allDevices.Count; i++)
        {
            if (allDevices[i].name.Equals(kHoloKitLeftHandName))
            {
                holoKitHands[0] = allDevices[i];
            }
            else if (allDevices[i].name.Equals(kHoloKitRightHandName))
            {
                holoKitHands[1] = allDevices[i];
            }
        }
    }

    void Update()
    {
         
    }
}
