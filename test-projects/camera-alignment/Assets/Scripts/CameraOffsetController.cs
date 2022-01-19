using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.XR.ARFoundation;

public class CameraOffsetController : MonoBehaviour
{
    bool m_IsUpButtonPressed;

    bool m_IsDownButtonPressed;

    bool m_IsLeftButtonPressed;

    bool m_IsRightButtonPressed;

    bool m_IsForwardButtonPressed;

    bool m_IsBackwardButtonPressed;

    Vector3 m_CameraOffset; // in right-handed coordinate space

    float m_OffsetUnit;

    [SerializeField] Text m_CameraOffsetText;

    [SerializeField] ARCameraBackground m_ARBackground;

    [SerializeField] Camera m_Camera0;

    [SerializeField] Camera m_Camera1;

    [DllImport("__Internal")]
    static extern void UnityHoloKit_SetCameraOffset(float x, float y, float z); // in right-handed coordinate space

    void Start()
    {
        m_IsUpButtonPressed = false;
        m_IsDownButtonPressed = false;
        m_IsLeftButtonPressed = false;
        m_IsRightButtonPressed = false;
        m_IsForwardButtonPressed = false;
        m_IsBackwardButtonPressed = false;
        m_CameraOffset = new Vector3(0f, 0f, 0f);
        m_OffsetUnit = 0.001f;
        m_CameraOffsetText.text = "(0.0000, 0.0000, 0.0000)";
        m_Camera0.targetDisplay = 0;
        m_Camera1.targetDisplay = 1;
    }

    void Update()
    {
        var cameras = FindObjectsOfType<Camera>();
        Debug.Log($"FOV0 {m_Camera0.fieldOfView} and target display {m_Camera0.targetDisplay}");
        Debug.Log($"FOV1 {m_Camera1.fieldOfView} and target display {m_Camera1.targetDisplay}");
        m_Camera1.fieldOfView = m_Camera0.fieldOfView;

        if (m_IsUpButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x, m_CameraOffset.y - m_OffsetUnit, m_CameraOffset.z);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }

        if (m_IsDownButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x, m_CameraOffset.y + m_OffsetUnit, m_CameraOffset.z);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }

        if (m_IsLeftButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x + m_OffsetUnit, m_CameraOffset.y, m_CameraOffset.z);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }

        if (m_IsRightButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x - m_OffsetUnit, m_CameraOffset.y, m_CameraOffset.z);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }

        if (m_IsForwardButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z - m_OffsetUnit);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }

        if (m_IsBackwardButtonPressed)
        {
            m_CameraOffset = new Vector3(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z + m_OffsetUnit);
            UnityHoloKit_SetCameraOffset(m_CameraOffset.x, m_CameraOffset.y, m_CameraOffset.z);
            m_CameraOffsetText.text = $"({m_CameraOffset.x.ToString("F4")}, {m_CameraOffset.y.ToString("F4")}, {m_CameraOffset.z.ToString("F4")})";
        }
    }

    public void OnUpButtonPressed()
    {
        m_IsUpButtonPressed = true;
    }

    public void OnUpButtonReleased()
    {
        m_IsUpButtonPressed = false;
    }

    public void OnDownButtonPressed()
    {
        m_IsDownButtonPressed = true;
    }

    public void OnDownButtonReleased()
    {
        m_IsDownButtonPressed = false;
    }

    public void OnLeftButtonPressed()
    {
        m_IsLeftButtonPressed = true;
    }

    public void OnLeftButtonReleased()
    {
        m_IsLeftButtonPressed = false;
    }

    public void OnRightButtonPressed()
    {
        m_IsRightButtonPressed = true;
    }

    public void OnRightButtonReleased()
    {
        m_IsRightButtonPressed = false;
    }

    public void OnForwardButtonPressed()
    {
        m_IsForwardButtonPressed = true;
    }

    public void OnForwardButtonReleased()
    {
        m_IsForwardButtonPressed = false;
    }

    public void OnBackwardButtonPressed()
    {
        m_IsBackwardButtonPressed = true;
    }

    public void OnBackwardButtonReleased()
    {
        m_IsBackwardButtonPressed = false;
    }

    public void ToggleARBackground()
    {
        if (m_Camera0.targetDisplay == 0)
        {
            m_Camera0.targetDisplay = 1;
            m_Camera1.targetDisplay = 0;
        }
        else
        {
            m_Camera0.targetDisplay = 0;
            m_Camera1.targetDisplay = 1;
        }
    }

    public void ResetOrigin()
    {
        FindObjectOfType<ARSession>().Reset();
    }
}
