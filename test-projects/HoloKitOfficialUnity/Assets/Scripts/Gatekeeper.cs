using System.Runtime.InteropServices;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Gatekeeper : MonoBehaviour
{
    public List<string> AvailableSceneNames = new List<string>();

    private bool m_IsFirstLoaded = true;

    [DllImport("__Internal")]
    public static extern void sendMessageToMobileApp(string message);

    private void Start()
    {
        if (m_IsFirstLoaded)
        {
            m_IsFirstLoaded = false;
            sendMessageToMobileApp("Loaded");
        }
    }

    // This function is called from the Swift side to enter demo scenes.
    public void PlayDemo(string demoName)
    {
        if (AvailableSceneNames.Contains(demoName))
        {
            SceneManager.LoadScene(demoName, LoadSceneMode.Single);
        }
        else
        {
            Debug.Log($"[Gatekeeper]: {demoName} is not valid.");
        }
    }
}