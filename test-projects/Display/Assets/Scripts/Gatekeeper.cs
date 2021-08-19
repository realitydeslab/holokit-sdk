using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Gatekeeper : MonoBehaviour
{
    private static Gatekeeper _instance;

    public static Gatekeeper Instance { get { return _instance; } }

    private string m_LobbyName = "FloatingBall";

    [DllImport("__Internal")]
    public static extern void sendMessageToMobileApp(string message); 

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

    private void Start()
    {
        sendMessageToMobileApp("Unity loaded");

        //if (FloatingBallUIManager.IsUnloading)
        //{
        //    //ebug.Log("Going to unload unity");
        //    //UnloadUnity();
        //}
    }

    public void EnterLobby(string message)
    {
        Debug.Log("Enter lobby.");
        SceneManager.LoadScene(m_LobbyName, LoadSceneMode.Single);
    }

    public void UnloadUnity()
    {
        Application.Unload();
        
    }
}
