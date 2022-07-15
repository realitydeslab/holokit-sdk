using UnityEngine;
using TMPro;
using HoloKit;

public class HoloKitRenderController : MonoBehaviour
{
    [SerializeField] private TMP_Text _renderModeText;

    private void Start()
    {
        if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Stereo)
        {
            _renderModeText.text = "Mono";
        }
        else
        {
            _renderModeText.text = "Stereo";
        }
    }

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
