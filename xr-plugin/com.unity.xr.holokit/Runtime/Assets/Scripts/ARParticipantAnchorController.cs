using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;

namespace UnityEngine.XR.HoloKit
{
    public class ARParticipantAnchorController : MonoBehaviour
    {
        private void Start()
        {
            string sessionId = GetComponent<ARParticipant>().sessionId.ToString();
            for (int i = 0; i < ARCollaborationManager.Instance.SessionIds.Count; i++)
            {
                if (ARCollaborationManager.Instance.SessionIds[i].ToString().Equals(sessionId))
                {
                    ARCollaborationManager.Instance.DidAddARParticipantAnchor((ulong)i, transform);
                }
            }
        }
    }
}