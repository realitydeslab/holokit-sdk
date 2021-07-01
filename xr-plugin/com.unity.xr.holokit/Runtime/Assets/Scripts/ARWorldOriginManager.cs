using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using System;
using MLAPI.Transports.MultipeerConnectivity;

namespace UnityEngine.XR.HoloKit
{
    public class ARWorldOriginManager : MonoBehaviour
    {
        // This class is a singleton.
        private static ARWorldOriginManager _instance;

        public static ARWorldOriginManager Instance { get { return _instance; } }

        /// <summary>
        /// Whether the AR maps of connected devices merged?
        /// </summary>
        [HideInInspector]
        public bool m_IsARCollaborationStarted = false;

        /// <summary>
        /// The time interval between two AR world origin resettings.
        /// </summary>
        [SerializeField]
        private float m_ResettingInverval = 30.0f;

        /// <summary>
        /// The time of last AR world origin resetting.
        /// </summary>
        private float m_LastResettingTime = 0.0f;

        /// <summary>
        /// Add an ARKit native anchor with an anchor name.
        /// </summary>
        /// <param name="anchorName">Anchor name</param>
        /// <param name="position">Anchor's position</param>
        /// <param name="rotation">Anchor's rotation</param>
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_AddNativeAnchor(string anchorName, float[] position, float[] rotation);

        /// <summary>
        /// This delegate gets called when the AR maps of connected devices merged successfully.
        /// </summary>
        delegate void ARCollaborationStarted();
        [AOT.MonoPInvokeCallback(typeof(ARCollaborationStarted))]
        static void OnARCollaborationStarted()
        {
            Debug.Log("[ARWorldOriginManager]: AR collaboration session started.");
            ARWorldOriginManager.Instance.m_IsARCollaborationStarted = true;
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARCollaborationStartedDelegate(ARCollaborationStarted callback);

        /// <summary>
        /// This delegate gets called when an origin anchor is received.
        /// </summary>
        delegate void OriginAnchorReceived(IntPtr positionPtr, IntPtr rotationPtr);
        [AOT.MonoPInvokeCallback(typeof(OriginAnchorReceived))]
        static void OnOriginAnchorReceived(IntPtr positionPtr, IntPtr rotationPtr)
        {
            float[] position = new float[3];
            Marshal.Copy(positionPtr, position, 0, 3);

            float[] rotation = new float[4];
            Marshal.Copy(rotationPtr, rotation, 0, 4);

            Debug.Log($"[ARWorldOriginManager]: AR world origin has been reset to position [{position[0]}, {position[1]}, {position[2]}, {position[3]}] " +
                $"and rotation [{rotation[0]}, {rotation[1]}, {rotation[2]}, {rotation[3]}].");
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetOriginAnchorReceivedDelegate(OriginAnchorReceived callback);

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(this.gameObject);
            }
            else
            {
                _instance = this;
            }
        }

        public void OnEnable()
        {
            // Register delegates
            UnityHoloKit_SetARCollaborationStartedDelegate(OnARCollaborationStarted);
            //UnityHoloKit_SetOriginAnchorReceivedDelegate(OnOriginAnchorReceived);
        }

        public void Update()
        {
            if (!m_IsARCollaborationStarted) return;

            if (MultipeerConnectivityTransport.Instance.m_IsHost && Time.time - m_LastResettingTime > m_ResettingInverval)
            {
                // Add origin anchor
                float[] position = { 0f, 0f, 0f };
                float[] rotation = { 0f, 0f, 0f, 1f };
                UnityHoloKit_AddNativeAnchor("-1", position, rotation);
                Debug.Log("[ARWorldOriginManager]: added an origin anchor.");
                m_LastResettingTime = Time.time;
            }
        }
    }
}