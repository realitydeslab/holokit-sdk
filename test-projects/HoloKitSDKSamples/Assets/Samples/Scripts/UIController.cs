using UnityEngine;
using TMPro;

namespace HoloKit.Samples.StereoscopicRendering
{
    public class UIController : MonoBehaviour
    {
        [SerializeField] private TMP_Text _renderModeText;

        private void Awake()
        {
            HoloKitCameraManager.OnHoloKitRenderModeChanged += OnHoloKitRenderModeChanged;
        }

        private void OnDestroy()
        {
            HoloKitCameraManager.OnHoloKitRenderModeChanged -= OnHoloKitRenderModeChanged;
        }

        public void ToggleRenderMode()
        {
            if (HoloKitCameraManager.Instance.RenderMode == HoloKitRenderMode.Stereo)
            {
                HoloKitCameraManager.Instance.RenderMode = HoloKitRenderMode.Mono;
            }
            else
            {
                HoloKitCameraManager.Instance.RenderMode = HoloKitRenderMode.Stereo;

                // Skip NFC scanning
                HoloKitCameraManager.Instance.OpenStereoWithoutNFC("SomethingForNothing");
            }
        }

        private void OnHoloKitRenderModeChanged(HoloKitRenderMode renderMode)
        {
            if (renderMode == HoloKitRenderMode.Stereo)
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