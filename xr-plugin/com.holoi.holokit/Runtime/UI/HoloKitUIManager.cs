using UnityEngine;

namespace Holoi.HoloKit.UI
{
    public class HoloKitUIManager : MonoBehaviour
    {
        [SerializeField] private GameObject _starPanel;

        [SerializeField] private RectTransform _phoneFrame;

        [SerializeField] private RectTransform _alignmenrMarker;

        private const float PHONE_FRAME_WIDTH_IN_METERS = 0.129871f;

        private const float PHONE_FRAME_HEIGHT_IN_METERS = 0.056322f;

        private const float METER_TO_INCH_RATIO = 39.3701f;

        private void Start()
        {
            SetupPhoneFrameAndAlignmentMarker();

            _starPanel.SetActive(false);
        }

        private void SetupPhoneFrameAndAlignmentMarker()
        {
            float screenDpi = HoloKitDeviceProfile.GetScreenDpi();
            float phoneFrameWidthInPixels = PHONE_FRAME_WIDTH_IN_METERS * METER_TO_INCH_RATIO * screenDpi;
            float phoneFrameHeightInPixels = PHONE_FRAME_HEIGHT_IN_METERS * METER_TO_INCH_RATIO * screenDpi;
            _phoneFrame.sizeDelta = new(phoneFrameWidthInPixels, phoneFrameHeightInPixels);

            float alignmentMarkerXInMeters = HoloKitDeviceProfile.GetHorizontalAlignmentMarkerOffset();
            float alignmentMarkerXInPixels = alignmentMarkerXInMeters * METER_TO_INCH_RATIO * screenDpi;
            _alignmenrMarker.anchoredPosition = new Vector2(alignmentMarkerXInPixels, 0f);
            _alignmenrMarker.sizeDelta = new(4f, HoloKitDeviceProfile.GetScreenHeight() - phoneFrameHeightInPixels);
        }

        public void SwitchRenderMode()
        {
            if (HoloKitCamera.Instance.RenderMode == HoloKitRenderMode.Mono)
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Stereo;
                _starPanel.SetActive(true);
            }
            else
            {
                HoloKitCamera.Instance.RenderMode = HoloKitRenderMode.Mono;
                _starPanel.SetActive(false);
            }
        }
    }
}
