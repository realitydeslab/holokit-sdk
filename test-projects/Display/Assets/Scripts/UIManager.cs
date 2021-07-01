using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MLAPI;

public class UIManager : MonoBehaviour
{
    private Button m_StartHostButton;

    private Button m_StartClientButton;

    private Button m_MoveButton;

    private Button m_SpawnVfxButton;

    void Start()
    {
        m_StartHostButton = transform.GetChild(0).GetComponent<Button>();
        m_StartHostButton.onClick.AddListener(StartHost);

        m_StartClientButton = transform.GetChild(1).GetComponent<Button>();
        m_StartClientButton.onClick.AddListener(StartClient);

        m_MoveButton = transform.GetChild(2).GetComponent<Button>();
        m_MoveButton.onClick.AddListener(Move);

        m_SpawnVfxButton = transform.GetChild(3).GetComponent<Button>();
        m_SpawnVfxButton.onClick.AddListener(SpawnVfx);
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
    }

    private void Move()
    {
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId,
                    out var networkedClient))
        {
            var player = networkedClient.PlayerObject.GetComponent<HelloWorld.HelloWorldPlayer>();
            if (player)
            {
                player.Move();
            }
        }
    }

    private void SpawnVfx()
    {
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkClient))
        {
            var player = networkClient.PlayerObject.GetComponent<HelloWorld.HelloWorldPlayer>();
            if (player)
            {
                player.SpawnVfx();
            }
        }
    }
}
