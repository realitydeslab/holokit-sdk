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

    private Text m_ServerClientIndicator;

    private Text m_NetworkVariable;

    private Button m_SpawnFlyingCubeButton;

    private Button m_MoveLeftButton;

    private Button m_MoveRightButton;

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

        m_ServerClientIndicator = transform.GetChild(4).GetComponent<Text>();

        m_NetworkVariable = transform.GetChild(5).GetComponent<Text>();

        m_SpawnFlyingCubeButton = transform.GetChild(6).GetComponent<Button>();
        m_SpawnFlyingCubeButton.onClick.AddListener(SpawnFlyingCube);

        m_MoveLeftButton = transform.GetChild(7).GetComponent<Button>();
        m_MoveLeftButton.onClick.AddListener(MoveLeft);

        m_MoveRightButton = transform.GetChild(8).GetComponent<Button>();
        m_MoveRightButton.onClick.AddListener(MoveRight);
    }

    void Update()
    {
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkedClient))
        {
            var player = networkedClient.PlayerObject.GetComponent<NetworkVariableTest>();
            if (player)
            {
                //m_NetworkVariable.text = $"server: {player.GetServerNetworkVariableValue()}, client: {player.GetClientNetworkVariableValue()} ";
                //m_NetworkVariable.text = $"server: {player.GetServerNetworkVariableValue()}";
            }
        }
    }

    private void StartHost()
    {
        NetworkManager.Singleton.StartHost();
        m_ServerClientIndicator.text = "Host";
    }

    private void StartClient()
    {
        NetworkManager.Singleton.StartClient();
        m_ServerClientIndicator.text = "Client";
    }

    private void Move()
    {
        //Debug.Log("[UIManager]: connected clients are");
        //foreach (ulong key in NetworkManager.Singleton.ConnectedClients.Keys)
        //{
        //    Debug.Log(key);
        //}
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkedClient))
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

    private void SpawnFlyingCube()
    {
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkClient))
        {
            var player = networkClient.PlayerObject.GetComponent<HelloWorld.HelloWorldPlayer>();
            if (player)
            {
                player.SpawnFlyingCubeServerRpc();
            }
        }
    }

    private void MoveLeft()
    {
        if (NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkClient))
        {
            var player = networkClient.PlayerObject.GetComponent<HelloWorld.HelloWorldPlayer>();
            if (player)
            {
                Vector3 direction = new Vector3(-1f, 0f, 0f);
                float magnitude = 100f;
                player.AddForce(direction.normalized, magnitude);
            }
        }
    }

    private void MoveRight()
    {
        if(NetworkManager.Singleton.ConnectedClients.TryGetValue(NetworkManager.Singleton.LocalClientId, out var networkClient))
        {
            var player = networkClient.PlayerObject.GetComponent<HelloWorld.HelloWorldPlayer>();
            if (player)
            {
                Vector3 direction = new Vector3(1f, 0f, 0f);
                float magnitude = 100f;
                player.AddForce(direction.normalized, magnitude);
            }
        }
    }
}