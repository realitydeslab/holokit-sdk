using UnityEngine;
using UnityEngine.SceneManagement;

public class HoloKitSceneManager : MonoBehaviour
{
    private static HoloKitSceneManager _instance;

    public static HoloKitSceneManager Instance { get { return _instance; } }

    private string m_EmptySceneName = "EmptyRoom";

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

    public void BackToEmptyScene()
    {
        SceneManager.LoadScene(m_EmptySceneName, LoadSceneMode.Single);
    }
}
