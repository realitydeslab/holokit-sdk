using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using UnityEngine.UI;

public class HolokitBaseGameManager : MonoBehaviour
{
    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    Button b_ModeSeletor;


    // Start is called before the first frame update
    void Start()
    {
        Transform ButtonConatiner = transform.GetChild(0);
        b_ModeSeletor = ButtonConatiner.GetChild(0).GetComponent<Button>(); // should be ar mode at initialization
        b_ModeSeletor.onClick.AddListener(OnClickModeSelector);
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    void OnClickModeSelector()
    {
        if (UnityHoloKit_GetRenderingMode()!= 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            b_ModeSeletor.transform.GetChild(0).GetComponent<Text>().text = "To\nAR";
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            b_ModeSeletor.transform.GetChild(0).GetComponent<Text>().text = "To\nMR";

        }
    }
}
