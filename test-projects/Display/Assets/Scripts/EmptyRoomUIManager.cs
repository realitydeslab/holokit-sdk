using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class EmptyRoomUIManager : MonoBehaviour
{
    private Button m_QuitButton;

    private Button m_NextButton;

    void Start()
    {
        m_QuitButton = transform.GetChild(0).GetComponent<Button>();
        m_QuitButton.onClick.AddListener(Quit);

        m_NextButton = transform.GetChild(1).GetComponent<Button>();
        m_NextButton.onClick.AddListener(Next);
    }

    private void Next()
    {
        SceneManager.LoadScene("FloatingBall", LoadSceneMode.Single);
    }

    private void Quit()
    {
        //Application.Unload();
        Gatekeeper.sendMessageToMobileApp("Hide unity");
    }


}
