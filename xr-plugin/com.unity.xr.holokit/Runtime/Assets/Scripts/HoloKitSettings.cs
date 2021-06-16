using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

public class HoloKitSettings : MonoBehaviour
{

    [SerializeField] private bool m_XrModeEnabled = true;

    private Camera arCamera;

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_SetRenderingMode(int val);

    void Start()
    {
        arCamera = Camera.main;

        // Set the rendering mode.
        if (m_XrModeEnabled)
        {
            UnityHoloKit_SetRenderingMode(2);
            arCamera.GetComponent<ARCameraBackground>().enabled = false;
        }
        else
        {
            UnityHoloKit_SetRenderingMode(1);
            arCamera.GetComponent<ARCameraBackground>().enabled = true;
        }

        // Set the screen brightness to the maximum.
        Screen.brightness = 1.0f;
    }

    void Update()
    {
        
    }
}
