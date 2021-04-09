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
            xrMode = false;
            txt.text = "AR Mode";
            RenderingSettings.EnableARBackground(false);
            Debug.Log("Display mode changed to AR mode.");
            
        } else
        {
            xrMode = true;
            txt.text = "XR Mode";
            RenderingSettings.EnableARBackground(true);
            Debug.Log("Display mode changed to XR mode.");
        }
    }
}
