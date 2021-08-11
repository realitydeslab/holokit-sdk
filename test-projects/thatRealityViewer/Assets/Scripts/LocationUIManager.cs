using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;

public class LocationUIManager : MonoBehaviour
{
    private Button m_InitLocationManagerButton;

    private Button m_StartUpdatingLocationButton;

    private Text m_LocationData;

    private Button m_StartRecordingButton;

    private Button m_FinishRecordingButton;

    private Button m_RenderingButton;

    private int m_FrameCount = 0;

    public static bool IsStereo = false;

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_StartRecording();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_FinishRecording();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_ActivateWatchConnectivitySession();

    private void Start()
    {
        m_InitLocationManagerButton = transform.GetChild(0).GetComponent<Button>();
        m_InitLocationManagerButton.onClick.AddListener(InitLocationManager);

        m_StartUpdatingLocationButton = transform.GetChild(1).GetComponent<Button>();
        m_StartUpdatingLocationButton.onClick.AddListener(StartUpdatingLocation);

        m_LocationData = transform.GetChild(2).GetComponent<Text>();

        m_StartRecordingButton = transform.GetChild(3).GetComponent<Button>();
        m_StartRecordingButton.onClick.AddListener(StartRecording);

        m_FinishRecordingButton = transform.GetChild(4).GetComponent<Button>();
        m_FinishRecordingButton.onClick.AddListener(FinishRecording);

        m_RenderingButton = transform.GetChild(5).GetComponent<Button>();
        m_RenderingButton.onClick.AddListener(SwitchRenderingMode);

        m_StartUpdatingLocationButton.gameObject.SetActive(false);

        UnityHoloKit_ActivateWatchConnectivitySession();
    }

    private void Update()
    {
        //Debug.Log($"Frame count: {++m_FrameCount}");
        HoloKitARBackgroundRendererFeature.CurrentRenderPass = 0;

        string newLocationData = $"Latitude: {LocationManager.Instance.CurrentLatitude}\n" +
            $"Longitude: {LocationManager.Instance.CurrentLongitude}\n" +
            $"Altitude: {LocationManager.Instance.CurrentAltitude}";
        m_LocationData.text = newLocationData;
    }

    private void InitLocationManager()
    {
        LocationManager.Instance.InitLocationManager();
        m_InitLocationManagerButton.gameObject.SetActive(false);
        m_StartUpdatingLocationButton.gameObject.SetActive(true);
    }

    private void StartUpdatingLocation()
    {
        LocationManager.Instance.StartUpdatingLocation();
    }

    private void StartRecording()
    {
        UnityHoloKit_StartRecording();
    }

    private void FinishRecording()
    {
        UnityHoloKit_FinishRecording();
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            //Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
            IsStereo = true;
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
            IsStereo = false;
        }
    }
}
