using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.XR.HoloKit {
    public class CameraRayCaster : MonoBehaviour
    {

        private float radius = 0.45f;

        private const float kMaxDistance = 10.0f;

        void Start()
        {

        }

        void Update()
        {
            RaycastHit hit;
            if (Physics.SphereCast(transform.position, radius, transform.forward, out hit, kMaxDistance))
            {
                if (hit.transform.tag == "HandInteractable")
                {
                    hit.transform.GetComponent<Renderer>().material.color = Color.cyan;
                    if (!HandTrackingManager.Instance.GetHandTrackingEnabled())
                    {
                        HandTrackingManager.Instance.EnableHandTracking();
                    }
            }
                else
                {
                    if (HandTrackingManager.Instance.GetHandTrackingEnabled())
                    {
                        HandTrackingManager.Instance.DisableHandTracking();
                    }
                }
            }
            else
            {
                if (HandTrackingManager.Instance.GetHandTrackingEnabled())
                {
                    HandTrackingManager.Instance.DisableHandTracking();
                }
            }
        }
    }
}