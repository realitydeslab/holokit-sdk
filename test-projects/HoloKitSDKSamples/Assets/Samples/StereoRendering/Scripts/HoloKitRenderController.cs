using UnityEngine;
using TMPro;
using HoloKit;

public class HoloKitRenderController : MonoBehaviour
{
    [SerializeField] private TMP_Text _renderModeText;

    public void ToggleRenderMode()
    {
        if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Stereo)
        {
            HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Mono;
            _renderModeText.text = "Stereo";
        }
        else
        {
            HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Stereo;
            _renderModeText.text = "Mono";
        }
    }
}
