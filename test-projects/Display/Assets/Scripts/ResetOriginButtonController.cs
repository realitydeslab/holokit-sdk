//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;
//using UnityEngine.UI;
//using UnityEngine.XR.HoloKit;

//public class ResetOriginButtonController : MonoBehaviour
//{

//    private Button m_ResetOriginButton;

//    void Start()
//    {
//        m_ResetOriginButton = GetComponent<Button>();
//        m_ResetOriginButton.onClick.AddListener(ResetOrigin);
//    }

//    void ResetOrigin()
//    {
//        // Send an anchor with the transform of the origin.
//        Debug.Log("[ResetOriginButtonController]: send origin resetting anchor.");
//        HoloKitAnchorManager.Instance.AddAnchor(-1, new Vector3(0f, 0f, 0f), new Quaternion(0f, 0f, 0f, 1f));
//    }
//}
