using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;

public class PlacementIndicator : MonoBehaviour
{
    [SerializeField] private GameObject m_Quad;

    private ARRaycastManager m_ARRaycastManager;

    private Camera m_ARCamera;

    private Pose m_PlacementPose;
    public Pose PlacementPose
    {
        get => m_PlacementPose;
    }

    private bool m_IsPlacementPoseValid = false;
    public bool IsPlacementPoseValid
    {
        get => m_IsPlacementPoseValid;
    }

    private void Start()
    {
        Debug.Log("[PlacementIndicator]: Start()");
        m_ARRaycastManager = FindObjectOfType<ARRaycastManager>();
        m_ARCamera = Camera.main;
    }

    private void Update()
    {
        UpdatePlacementPose();
        UpdatePlacementIndicator();
    }

    private void UpdatePlacementPose()
    {
        var screenCenter = m_ARCamera.ViewportToScreenPoint(new Vector3(0.5f, 0.5f));
        var hits = new List<ARRaycastHit>();
        m_ARRaycastManager.Raycast(screenCenter, hits, UnityEngine.XR.ARSubsystems.TrackableType.Planes);

        m_IsPlacementPoseValid = hits.Count > 0;
        if (m_IsPlacementPoseValid)
        {
            m_PlacementPose = hits[0].pose;

            var cameraForward = m_ARCamera.transform.forward;
            var cameraBearing = new Vector3(cameraForward.x, 0f, cameraForward.z).normalized;
            m_PlacementPose.rotation = Quaternion.LookRotation(cameraBearing);
        }
    }

    private void UpdatePlacementIndicator()
    {
        if (m_IsPlacementPoseValid)
        {
            m_Quad.SetActive(true);
            transform.SetPositionAndRotation(m_PlacementPose.position, m_PlacementPose.rotation);
        }
        else
        {
            m_Quad.SetActive(false);
        }
    }
}
