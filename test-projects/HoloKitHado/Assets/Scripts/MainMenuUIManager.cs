using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class MainMenuUIManager : MonoBehaviour
{
    private Button m_StartPvPButton;

    private Button m_StartPPvEButton;

    private string m_PvPSceneName = "HadoTestScene";

    private string m_PPvESceneName = "PPvE";

    private void Start()
    {
        m_StartPvPButton = transform.GetChild(0).GetComponent<Button>();
        m_StartPvPButton.onClick.AddListener(StartPvP);

        m_StartPPvEButton = transform.GetChild(1).GetComponent<Button>();
        m_StartPPvEButton.onClick.AddListener(StartPPvE);
    }

    private void StartPvP()
    {
        SceneManager.LoadScene(m_PvPSceneName, LoadSceneMode.Single);
    }

    private void StartPPvE()
    {
        SceneManager.LoadScene(m_PPvESceneName, LoadSceneMode.Single);
    }
}
