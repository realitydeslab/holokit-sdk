using UnityEngine;
//#if Platform_IOS
using UnityEngine.Apple.ReplayKit;

public class ReplayManager : MonoBehaviour
{
    // This class is a singleton.
    private static ReplayManager _instance;

    public static ReplayManager Instance { get { return _instance; } }

    private bool m_IsRecording = false;

    public bool IsRecording
    {
        get => m_IsRecording;
    }

    public bool IsPreviewAvailable
    {
        get => ReplayKit.recordingAvailable;
    }

    private void Awake()
    {
        if (_instance != null && _instance != this)
        {
            Destroy(this.gameObject);
        }
        else
        {
            _instance = this;
        }
    }

    private void Update()
    {
        //if (ReplayKit.isRecording)
        //    ReplayKit.ShowCameraPreviewAt(10, 350, 200, 200);
        //else
        //    ReplayKit.HideCameraPreview();
    }

    public void StartRecording()
    {
        if (!ReplayKit.APIAvailable)
        {
            Debug.Log("[ReplayKit]: API not available");
            return;
        }

        if(!m_IsRecording)
        {
            if (ReplayKit.StartRecording(true, false) )
            {
                Debug.Log("[ReplayKit]: start recording successfully");
                m_IsRecording = true;
            }
            else
            {
                Debug.Log("[ReplayKit]: start recording unsuccessfully");
            }
            
        }
    }

    public void StopRecording()
    {
        if (m_IsRecording)
        {
            m_IsRecording = false;
            if (ReplayKit.StopRecording())
            {
                Debug.Log("[ReplayKit]: stop recording successfully");
            }
            else
            {
                Debug.Log("[ReplayKit]: stop recroding unsuccessfully");
            }
            
        }
    }

    public void Preview()
    {
        if (ReplayKit.recordingAvailable)
        {
            ReplayKit.Preview();
        }
    }
}
//#endif