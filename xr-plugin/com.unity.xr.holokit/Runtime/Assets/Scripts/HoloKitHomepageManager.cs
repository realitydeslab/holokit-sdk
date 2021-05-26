using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.SceneManagement;
using System.Runtime.InteropServices;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitHomepageManager : MonoBehaviour
    {
        [SerializeField] private string sceneName;

        private Button signInButton;

        private bool m_AutoLoginAttempted = false;

        [DllImport("__Internal")]
        public static extern bool UnityHoloKit_SetIsXrModeEnabled(bool val);

        public delegate void AutoLoginAction();
        public static event AutoLoginAction OnAutoLoginStarted;

        public delegate void LoginButtonAction();
        public static event LoginButtonAction OnLoginButtonPressed;

        private void OnEnable()
        {
            var rootVisualElement = GetComponent<UIDocument>().rootVisualElement;
            signInButton = rootVisualElement.Q<Button>("sign-in-button");

            signInButton.RegisterCallback<ClickEvent>(ev => SignIn());
        }

        private void Update()
        {
            if (!m_AutoLoginAttempted)
            {
                OnAutoLoginStarted();
                m_AutoLoginAttempted = true;
            }
        }

        private void SignIn()
        {
            //Debug.Log("Apple account signed in.");

            //OnLoginButtonPressed();
            
            SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Single);
            UnityHoloKit_SetIsXrModeEnabled(true);
        }
    }
}