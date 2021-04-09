using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ButtonHandler : MonoBehaviour
{
    bool xrMode = false;

    public void SwitchDisplayMode()
    {
        Text txt = transform.Find("Text").GetComponent<Text>();
        if(xrMode)
        {
            // XR mode
            if (RenderingSettings.EnableARBackground(true))
            {
                xrMode = false;
                txt.text = "AR Mode";
                Debug.Log("Display mode changed to AR mode.");
            }
        }
        else
        {
            // AR mode
            if (RenderingSettings.EnableARBackground(false))
            {
                xrMode = true;
                txt.text = "XR Mode";
                Debug.Log("Display mode changed to XR mode.");
            }
        }
    }
}
