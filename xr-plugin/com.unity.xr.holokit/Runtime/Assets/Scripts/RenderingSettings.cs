using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR.ARFoundation;
using System.Runtime.InteropServices;

public class RenderingSettings : MonoBehaviour
{
    static ARCameraBackground camBackground;

    [SerializeField]
    private bool arBackgroundEnabled = true;

    [DllImport("__Internal")]
    public static extern bool UnityHoloKit_SetIsXrModeEnabled(bool val);

    // Start is called before the first frame update
    void Start()
    {
        camBackground = FindObjectOfType<ARCameraBackground>();
        camBackground.enabled = arBackgroundEnabled;

        // TODO: adjust brightness when switching to XR mode
        Screen.brightness = 1.0f;
    }

    // Update is called once per frame
    void Update()
    {

    }

    public static bool EnableARBackground(bool val)
    {
       
        if (UnityHoloKit_SetIsXrModeEnabled(!val))
        {
            camBackground.enabled = val;
            return true;
        }
        else
        {
            return false;
        }
    }
}