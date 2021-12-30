using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitHandMovementManager : MonoBehaviour
    {
        private Vector3 m_TargetPosition;
        HoloKitHandTracking HKHT;
        [SerializeField] Transform m_ArkitHand;
        [SerializeField] float m_Speed = 1f;

        enum HandTrackingMode
        {
            Holokit,
            Arkit
        }

        [SerializeField] HandTrackingMode M_HandTrackingMode = HandTrackingMode.Arkit;

        void Start()
        {
            // if we use amber hand tracking manager
            HKHT = FindObjectOfType<HoloKitHandTracking>();
            // if we use arkit hand tracking manager
            
        }


        void Update()
        {
            if(M_HandTrackingMode == HandTrackingMode.Arkit) {
                m_TargetPosition = m_ArkitHand.position;
            }
            else
            {
                m_TargetPosition = HKHT.CurrentHandPosition;
            }

            transform.position += (m_TargetPosition - transform.position) * Time.deltaTime * m_Speed;
        }
    }
}