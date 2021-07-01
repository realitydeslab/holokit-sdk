using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MLAPI;

public class BuddhaUIManager : MonoBehaviour
{

    private Button m_StartHostButton;

    private Button m_StartClientButton;
    
    void Start()
    {
        m_StartHostButton = transform.GetChild(0).GetComponent<Button>();
        m_StartHostButton.onClick.AddListener(StartHost);

        m_StartClientButton = transform.GetChild(1).GetComponent<Button>();
        m_StartClientButton.onClick.AddListener(StartClient);
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
        DisableNetworkButtons();
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
        DisableNetworkButtons();
    }

    private void DisableNetworkButtons()
    {
        m_StartHostButton.gameObject.SetActive(false);
        m_StartClientButton.gameObject.SetActive(false);
    }
}
