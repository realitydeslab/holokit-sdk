using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.SceneManagement;
using System.Runtime.InteropServices;

public class UIBuilderManager : MonoBehaviour
{
    [SerializeField] private string sceneName;

    private Button signInButton;

    [DllImport("__Internal")]
    public static extern bool UnityHoloKit_SetIsXrModeEnabled(bool val);

    private void OnEnable()
    {
        var rootVisualElement = GetComponent<UIDocument>().rootVisualElement;
        signInButton = rootVisualElement.Q<Button>("sign-in-button");

        signInButton.RegisterCallback<ClickEvent>(ev => SignIn());
    }

    private void SignIn()
    {
        Debug.Log("Apple account signed in.");
        SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Single);
        UnityHoloKit_SetIsXrModeEnabled(true);
    }
}
