using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.HoloKit;

public class LocationUIManager : MonoBehaviour
{
    private Button m_StartRecordingButton;

    private Button m_FinishRecordingButton;

    private Button m_RenderingButton;

    private Button m_OpenLLTButton;

    private Button m_CloseLLTButton;

    private Button m_OpenFilterButton;

    private Button m_CloseFilterButton;

    public static bool IsStereo = false;

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_StartRecording();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_FinishRecording();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_ActivateWatchConnectivitySession();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetLowLatencyTrackingApiActive(bool value);

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetIsFilteringGyro(bool value);

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetIsFilteringAcc(bool value);

    private void Start()
    {
        m_StartRecordingButton = transform.GetChild(0).GetComponent<Button>();
        m_StartRecordingButton.onClick.AddListener(StartRecording);

        m_FinishRecordingButton = transform.GetChild(1).GetComponent<Button>();
        m_FinishRecordingButton.onClick.AddListener(FinishRecording);

        m_RenderingButton = transform.GetChild(2).GetComponent<Button>();
        m_RenderingButton.onClick.AddListener(SwitchRenderingMode);

        m_OpenLLTButton = transform.GetChild(3).GetComponent<Button>();
        m_OpenLLTButton.onClick.AddListener(OpenLLT);

        m_CloseLLTButton = transform.GetChild(4).GetComponent<Button>();
        m_CloseLLTButton.onClick.AddListener(CloseLLT);

        m_OpenFilterButton = transform.GetChild(5).GetComponent<Button>();
        m_OpenFilterButton.onClick.AddListener(OpenFilter);

        m_CloseFilterButton = transform.GetChild(6).GetComponent<Button>();
        m_CloseFilterButton.onClick.AddListener(CloseFilter);

        UnityHoloKit_ActivateWatchConnectivitySession();
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
        if (!HoloKitSettings.Instance.StereoscopicRendering)
        {
            // Switch to XR mode.
            HoloKitSettings.Instance.SetStereoscopicRendering(true);
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
            IsStereo = true;
        }
        else
        {
            // Switch to AR mode.
            HoloKitSettings.Instance.SetStereoscopicRendering(false);
            m_RenderingButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
            IsStereo = false;
        }
    }

    private void OpenLLT()
    {
        UnityHoloKit_SetLowLatencyTrackingApiActive(true);
    }

    private void CloseLLT()
    {
        UnityHoloKit_SetLowLatencyTrackingApiActive(false);
    }

    private void OpenFilter()
    {
        UnityHoloKit_SetIsFilteringGyro(true);
        UnityHoloKit_SetIsFilteringAcc(true);
    }

    private void CloseFilter()
    {
        UnityHoloKit_SetIsFilteringGyro(false);
        UnityHoloKit_SetIsFilteringAcc(false);
    }
}
