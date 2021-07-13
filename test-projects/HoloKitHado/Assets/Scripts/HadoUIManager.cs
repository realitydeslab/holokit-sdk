using UnityEngine;
using UnityEngine.UI;
using MLAPI;
using System.Runtime.InteropServices;

public class HadoUIManager : MonoBehaviour
{
    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Button m_SwitchRenderingModeButton;

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetRenderingMode(int val);

    private void Start()
    {
        m_StartHostButton = transform.GetChild(0).GetComponent<Button>();
        m_StartHostButton.onClick.AddListener(StartHost);

        m_StartClientButton = transform.GetChild(1).GetComponent<Button>();
        m_StartClientButton.onClick.AddListener(StartClient);

        m_SwitchRenderingModeButton = transform.GetChild(2).GetComponent<Button>();
        m_SwitchRenderingModeButton.onClick.AddListener(SwitchRenderingMode);
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
    }

    private void SwitchRenderingMode()
    {
        if (UnityHoloKit_GetRenderingMode() != 2)
        {
            UnityHoloKit_SetRenderingMode(2);
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "AR";
        }
        else
        {
            UnityHoloKit_SetRenderingMode(1);
            m_SwitchRenderingModeButton.transform.GetChild(0).GetComponent<Text>().text = "XR";
        }
    }
}
