using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitManager : MonoBehaviour
    {
        public static readonly Vector3 CameraToCenterEyeOffset = new(0.0495f, -0.090635f, -0.07965f);

        private void Awake()
        {
            Screen.brightness = 1.0f;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            iOS.Device.hideHomeButton = true;

            var centerEye = FindObjectOfType<CenterEye>();

            var background = FindObjectOfType<ARCameraBackground>();
            if (HoloKitApi.GetStereoScopicRendering())
            {
                background.enabled = false;
                if (centerEye)
                {
                    centerEye.transform.localPosition = CameraToCenterEyeOffset;
                }
            }
            else
            {
                background.enabled = true;
                if (centerEye)
                {
                    centerEye.transform.localPosition = Vector3.zero;
                }
            }
        }
    }
}