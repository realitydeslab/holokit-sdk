using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using AppleAuth;
using AppleAuth.Enums;
using AppleAuth.Extensions;
using AppleAuth.Interfaces;
using AppleAuth.Native;

namespace UnityEngine.XR.HoloKit
{
    public class AppleSignInManager : MonoBehaviour
    {
        private const string AppleUserIdKey = "AppleUserId";

        private IAppleAuthManager m_AppleAuthManager;

        private void OnEnable()
        {
            UnityEngine.XR.HoloKit.HoloKitHomepageManager.OnAutoLoginStarted += SignInStart;
            UnityEngine.XR.HoloKit.HoloKitHomepageManager.OnLoginButtonPressed += SignInWithApple;
        }

        private void OnDisable()
        {
            UnityEngine.XR.HoloKit.HoloKitHomepageManager.OnAutoLoginStarted -= SignInStart;
            UnityEngine.XR.HoloKit.HoloKitHomepageManager.OnLoginButtonPressed -= SignInWithApple;
        }

        // Start is called before the first frame update
        void Start()
        {

            if (AppleAuthManager.IsCurrentPlatformSupported)
            {
                // Creates a default JSON deserializer, to transform JSON Native responses to C# instances
                var deserializer = new PayloadDeserializer();
                // Creates an Apple Authentication manager with the deserializer
                m_AppleAuthManager = new AppleAuthManager(deserializer);
            }

            // TODO: SetCredentialsRevokedCallback
        }

        // Update is called once per frame
        void Update()
        {
            if (m_AppleAuthManager != null)
            {
                m_AppleAuthManager.Update();
            }
        }

        void SignInStart()
        {

            // If we have an Apple User Id available, get the credential status for it
            if (PlayerPrefs.HasKey(AppleUserIdKey))
            {
                var storedAppleUserId = PlayerPrefs.GetString(AppleUserIdKey);
                CheckCredentialStatusForUserId(storedAppleUserId);
            }
            // If we do not have an stored Apple User Id, attempt a quick login
            else
            {
                AttemptQuickLogin();
            }

        }

        private void CheckCredentialStatusForUserId(string appleUserId)
        {
            // If there is an apple ID available, we should check the credential state
            m_AppleAuthManager.GetCredentialState(
                appleUserId,
                state =>
                {
                    switch (state)
                    {
                    // If it's authorized, login with that user id
                    case CredentialState.Authorized:
                            return;

                    // If it was revoked, or not found, we need a new sign in with apple attempt
                    // Discard previous apple user id
                    case CredentialState.Revoked:
                        case CredentialState.NotFound:
                            PlayerPrefs.DeleteKey(AppleUserIdKey);
                            return;
                    }
                },
                error =>
                {
                    var authorizationErrorCode = error.GetAuthorizationErrorCode();
                    Debug.LogWarning("Error while trying to get credential state " + authorizationErrorCode.ToString() + " " + error.ToString());
                });
        }

        void SignInWithApple()
        {
            Debug.Log("Apple login.");

            var loginArgs = new AppleAuthLoginArgs(LoginOptions.IncludeEmail | LoginOptions.IncludeFullName);

            m_AppleAuthManager.LoginWithAppleId(
                loginArgs,
                credential =>
                {
                    // Obtained credential, cast it to IAppleIDCredential
                    var appleIdCredential = credential as IAppleIDCredential;
                    if (appleIdCredential != null)
                    {
                        // Apple User ID
                        // You should save the user ID somewhere in the device
                        var userId = appleIdCredential.User;
                        PlayerPrefs.SetString(AppleUserIdKey, userId);

                        // Email (Received ONLY in the first login)
                        var email = appleIdCredential.Email;

                        // Full name (Received ONLY in the first login)
                        var fullName = appleIdCredential.FullName;

                        //// Identity token
                        //var identityToken = Encoding.UTF8.GetString(
                        //                appleIdCredential.IdentityToken,
                        //                0,
                        //                appleIdCredential.IdentityToken.Length);

                        //// Authorization code
                        //var authorizationCode = Encoding.UTF8.GetString(
                        //                appleIdCredential.AuthorizationCode,
                        //                0,
                        //                appleIdCredential.AuthorizationCode.Length);

                        // And now you have all the information to create/login a user in your system
                    }
                },
                error =>
                {
                    // Something went wrong
                    var authorizationErrorCode = error.GetAuthorizationErrorCode();
                    Debug.LogWarning("Sign in with Apple failed " + authorizationErrorCode.ToString() + " " + error.ToString());
                });
        }

        void AttemptQuickLogin()
        {
            Debug.Log("Apple quick login.");

            var quickLoginArgs = new AppleAuthQuickLoginArgs();

            m_AppleAuthManager.QuickLogin(
                quickLoginArgs,
                credential =>
                {
                    var appleIdCredential = credential as IAppleIDCredential;

                    var passwordCredential = credential as IPasswordCredential;
                },
                error =>
                {
                    // Quick login failed.
                    var authorizationErrorCode = error.GetAuthorizationErrorCode();
                    Debug.LogWarning("Quick Login Failed " + authorizationErrorCode.ToString() + " " + error.ToString());
                });
        }
    }
}