using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEngine.SceneManagement;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitHomepageManager : MonoBehaviour
    {
        [SerializeField] private string sceneName;

        private Button signInButton;

        private Button XrModeButton;

        private Button ArModeButton;

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
                    XrModeButton.SetEnabled(true);
                    XrModeButton.visible = true;
                    ArModeButton.SetEnabled(true);
                    ArModeButton.visible = true;
                }
                else
                {
                    XrModeButton.SetEnabled(false);
                    XrModeButton.visible = false;
                    ArModeButton.SetEnabled(false);
                    ArModeButton.visible = false;
                }
            }
        }

        private void SetupOrientationSwitchWindow()
        {
            m_UIDocument.visualTreeAsset = m_OrientationSwitchWindowAsset;
            var rootVisualElement = m_UIDocument.rootVisualElement;
            XrModeButton = rootVisualElement.Q<Button>("xr-mode-button");
            XrModeButton.RegisterCallback<ClickEvent>(ev => EnterXrMode());
            XrModeButton.SetEnabled(false);
            XrModeButton.visible = false;

            ArModeButton = rootVisualElement.Q<Button>("ar-mode-button");
            ArModeButton.RegisterCallback<ClickEvent>(ev => EnterArMode());
            ArModeButton.SetEnabled(false);
            ArModeButton.visible = false;

            m_InOrientationSwith = true;
        }

        private void SignIn()
        {
            //Debug.Log("Apple account signed in.");

            OnLoginButtonPressed();
            SetupOrientationSwitchWindow();
        }

        private void SetupStarterScene()
        {
            Screen.autorotateToLandscapeRight = false;
            Screen.autorotateToPortrait = false;
            Screen.autorotateToPortraitUpsideDown = false;
            //UnityHoloKit_StartNfcVerification();
            m_InOrientationSwith = false;

            Debug.Log("SetupStarterScene.");
            SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Single);
        }

        private void EnterXrMode()
        {
            Debug.Log("Enter XR mode.");
            UnityHoloKit_SetRenderingMode(2);
            SetupStarterScene();
        }

        private void EnterArMode()
        {
            Debug.Log("Enter AR mode.");
            UnityHoloKit_SetRenderingMode(1);
            SetupStarterScene();
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
        }
    }
}