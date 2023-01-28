using UnityEngine;
using TMPro;

namespace Holoi.HoloKit.Samples.StereoscopicRendering
{
    public class UIController : MonoBehaviour
    {
        [SerializeField] private TMP_Text _renderModeText;

        public void ToggleRenderMode()
        {
            if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Stereo)
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Mono;
            }
            else
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Stereo;
            }

            if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Stereo)
            {
                _renderModeText.text = "Mono";
            }
            else
            {
                _renderModeText.text = "Stereo";
            }
        }
    }
}