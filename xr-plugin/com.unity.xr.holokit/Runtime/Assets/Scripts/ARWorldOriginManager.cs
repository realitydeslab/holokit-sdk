using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using System;
using MLAPI;

namespace UnityEngine.XR.HoloKit
{
    public class ARWorldOriginManager : MonoBehaviour
    {
        // This class is a singleton.
        private static ARWorldOriginManager _instance;

        public static ARWorldOriginManager Instance { get { return _instance; } }

        /// <summary>
        /// Has my AR world map been synced with others in the network?
        /// This variable is set to true when the local AR collaboration sessino begins.
        /// </summary>
        private bool m_IsARWorldMapSynced = false;

        public bool IsARWorldMapSynced => m_IsARWorldMapSynced;

        /// <summary>
        /// The time interval between two AR world origin resettings.
        /// </summary>
        private float m_ResettingInterval = 5.0f;

        private const float k_ResettingIntervalIncreament = 20.0f;

        /// <summary>
        /// The time of last AR world origin resetting.
        /// </summary>
        private float m_LastResettingTime = 0.0f;

        private int m_SyncedClientsNum = 0;

        public int SyncedClientsNum
        {
            get => m_SyncedClientsNum;
        }

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
        delegate void ARWorldMapSynced();
        [AOT.MonoPInvokeCallback(typeof(ARWorldMapSynced))]
        static void OnARWorldMapSynced()
        {
            //Debug.Log("[ARWorldOriginManager]: AR collaboration session started.");
            ARWorldOriginManager.Instance.m_IsARWorldMapSynced = true;
            if (NetworkManager.Singleton.IsServer)
            {
                Instance.m_SyncedClientsNum++;
            }
        }
        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetARWorldMapSyncedDelegate(ARWorldMapSynced callback);

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
            UnityHoloKit_SetARWorldMapSyncedDelegate(OnARWorldMapSynced);
        }

        public void Update()
        {
            if (!m_IsARWorldMapSynced) return;

            if (NetworkManager.Singleton.IsServer && Time.time - m_LastResettingTime > m_ResettingInterval)
            {
                // Add origin anchor
                float[] position = { 0f, 0f, 0f };
                float[] rotation = { 0f, 0f, 0f, 1f };
                UnityHoloKit_AddNativeAnchor("-1", position, rotation);
                Debug.Log("[ARWorldOriginManager]: added an origin anchor.");
                m_LastResettingTime = Time.time;
                // We gradually increase the resetting interval.
                m_ResettingInterval += k_ResettingIntervalIncreament;
            }
        }
    }
}