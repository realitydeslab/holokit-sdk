using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR.ARFoundation;
using System.Runtime.InteropServices;

public class RenderingSettings : MonoBehaviour
{
    static ARCameraBackground camBackground;

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_SetIsXrModeEnabled(bool val);

    // Start is called before the first frame update
    void Start()
    {
        camBackground = FindObjectOfType<ARCameraBackground>();
        if (camBackground)
        {
            Debug.Log("hey");
        }
        camBackground.enabled = true;
    }

    // Update is called once per frame
    void Update()
    {

    }

    public static void EnableARBackground(bool val)
    {
        camBackground.enabled = val;
        UnityHoloKit_SetIsXrModeEnabled(!val);
    }
}