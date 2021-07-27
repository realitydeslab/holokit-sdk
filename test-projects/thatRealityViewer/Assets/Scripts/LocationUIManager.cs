using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;

public class LocationUIManager : MonoBehaviour
{
    private Button m_InitLocationManagerButton;

    private Button m_StartUpdatingLocationButton;

    private Text m_LocationData;

    private Button m_RecordingButton;

    private Button m_PreviewButton;

    private Button m_RenderingButton;

    private int m_FrameCount = 0;

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    private void Start()
    {
        m_InitLocationManagerButton = transform.GetChild(0).GetComponent<Button>();
        m_InitLocationManagerButton.onClick.AddListener(InitLocationManager);

        m_StartUpdatingLocationButton = transform.GetChild(1).GetComponent<Button>();
        m_StartUpdatingLocationButton.onClick.AddListener(StartUpdatingLocation);

        m_LocationData = transform.GetChild(2).GetComponent<Text>();

        m_RecordingButton = transform.GetChild(3).GetComponent<Button>();
        m_RecordingButton.onClick.AddListener(Record);

        m_PreviewButton = transform.GetChild(4).GetComponent<Button>();
        m_PreviewButton.onClick.AddListener(Preview);

        m_RenderingButton = transform.GetChild(5).GetComponent<Button>();
        m_RenderingButton.onClick.AddListener(SwitchRenderingMode);

        m_StartUpdatingLocationButton.gameObject.SetActive(false);
    }

    private void Update()
    {
        Debug.Log($"Frame count: {++m_FrameCount}");

        string newLocationData = $"Latitude: {LocationManager.Instance.CurrentLatitude}\n" +
            $"Longitude: {LocationManager.Instance.CurrentLongitude}\n" +
            $"Altitude: {LocationManager.Instance.CurrentAltitude}";
        m_LocationData.text = newLocationData;

        if (ReplayManager.Instance.IsPreviewAvailable)
        {
            m_PreviewButton.gameObject.SetActive(true);
        }
        else
        {
            m_PreviewButton.gameObject.SetActive(false);
        }
    }

    private void InitLocationManager()
    {
        LocationManager.Instance.InitLocationManager();
        m_InitLocationManagerButton.gameObject.SetActive(false);
        m_StartUpdatingLocationButton.gameObject.SetActive(true);
    }

    private void StartUpdatingLocation()
    {
        LocationManager.Instance.StartUpdateLocation();
    }

    private void Record()
    {
        if (!ReplayManager.Instance.IsRecording)
        {
            ReplayManager.Instance.StartRecording();
            m_RecordingButton.transform.GetChild(0).GetComponent<Text>().text = "Stop Recording";
        }
        else
        {
            ReplayManager.Instance.StopRecording();
            m_RecordingButton.transform.GetChild(0).GetComponent<Text>().text = "Start Recording";
        }
    }

    private void Preview()
    {
        ReplayManager.Instance.Preview();
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            // Switch to XR mode.
            UnityHoloKit_SetRenderingMode(2);
            Camera.main.GetComponent<ARCameraBackground>().enabled = false;
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
        }
        else
        {
            // Switch to AR mode.
            UnityHoloKit_SetRenderingMode(1);
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
        }
    }
}
