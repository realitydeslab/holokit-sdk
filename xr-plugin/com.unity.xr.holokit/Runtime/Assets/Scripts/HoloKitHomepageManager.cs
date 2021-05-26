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

        private bool m_InOrientationSwith = false;

        private UIDocument m_UIDocument;

        [SerializeField] private VisualTreeAsset m_OrientationSwitchWindowAsset;

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_SetRenderingMode(int val);

        [DllImport("__Internal")]
        public static extern void UnityHoloKit_StartNfcVerification();

        public delegate void AutoLoginAction();
        public static event AutoLoginAction OnAutoLoginStarted;

        public delegate void LoginButtonAction();
        public static event LoginButtonAction OnLoginButtonPressed;

        private void OnEnable()
        {
            m_UIDocument = GetComponent<UIDocument>();
            var rootVisualElement = m_UIDocument.rootVisualElement;
            signInButton = rootVisualElement.Q<Button>("sign-in-button");

            signInButton.RegisterCallback<ClickEvent>(ev => SignIn());
        }

        private void Update()
        {
            if (!m_AutoLoginAttempted)
            {
                // Attemp an automatic login
                OnAutoLoginStarted();
                m_AutoLoginAttempted = true;
            }

            if (m_InOrientationSwith)
            {
                if (Screen.orientation == ScreenOrientation.LandscapeLeft)
                {
                    Screen.autorotateToLandscapeRight = false;
                    Screen.autorotateToPortrait = false;
                    Screen.autorotateToPortraitUpsideDown = false;
                    UnityHoloKit_StartNfcVerification();
                    m_InOrientationSwith = false;

                    SetupStarterScene();
                }
            }
        }

        private void SetupOrientationSwitchWindow()
        {
            m_UIDocument.visualTreeAsset = m_OrientationSwitchWindowAsset;
            m_InOrientationSwith = true;
        }

        private void SignIn()
        {
            //Debug.Log("Apple account signed in.");

            //OnLoginButtonPressed();

            SetupOrientationSwitchWindow();
        }

        private void SetupStarterScene()
        {
            SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Single);
            UnityHoloKit_SetRenderingMode(2);
        }
    }
}