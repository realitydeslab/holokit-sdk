using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class ARTapToPlaceObject : MonoBehaviour
{
    public GameObject objectToPlace;
    //public GameObject placementIndicator;
    [SerializeField] Text m_Text;
    [SerializeField] Transform LineRenderer;

    private ARRaycastManager arRayManager;
    private Pose m_PlacementPose;
    private bool m_PlacementPoseIsValid = false;

    public Pose PlacementPose
    {
        get { return m_PlacementPose; }
    }
    public bool PlacementPoseIsValid
    {
        get { return m_PlacementPoseIsValid; }
    }

    enum Mode 
    {
        ARMode,
        MRMode,
        Spectator
    }
    Mode m_Mode = Mode.ARMode;

    public Pose aim
    {
        get { return m_PlacementPose; }
    }
    public void OnModeButtonClicked()
    {
        if (m_Mode == Mode.ARMode)
            m_Mode = Mode.MRMode;

        if (m_Mode == Mode.MRMode)
            m_Mode = Mode.ARMode;
    }


    void Start()
    {
        arRayManager = FindObjectOfType<ARRaycastManager>();
    }

    void Update()
    {
        switch (m_Mode)
        {
            case Mode.ARMode:
                UpdatePlacementPose();
                UpdatePlacementIndicator();
                // touch screen to trigger function
                //if (m_PlacementPoseIsValid && Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Began && !IsPointerOverUIObject())
                //{
                //    PlaceObject();
                //}
                break;
            case Mode.MRMode:
                UpdatePlacementPose();
                UpdatePlacementIndicator();
                break;
            case Mode.Spectator:
                break; 
        }
    }

    public void PlaceObject()
    {
        Instantiate(objectToPlace, m_PlacementPose.position, m_PlacementPose.rotation);
        //
        //placementIndicator.SetActive(false);
        FindObjectOfType<VFXLineRenderer>().gameObject.SetActive(false);
        FindObjectOfType<ARPlaneManager>().enabled = false;
        FindObjectOfType<MenuSimple>().gameObject.SetActive(false);
    }

    private void UpdatePlacementIndicator()
    {
        if (m_PlacementPoseIsValid)
        {
            //placementIndicator.SetActive(true);
            Debug.Log("set indicator postion in UpdatePlacementIndicator()");
            Debug.Log(m_PlacementPose.position);
            Debug.Log(m_PlacementPose.rotation);
            //placementIndicator.transform.SetPositionAndRotation(m_PlacementPose.position, m_PlacementPose.rotation);
            LineRenderer.gameObject.SetActive(true);
            m_Text.text = "Touch to Place";
        }
        else
        {
            //placementIndicator.SetActive(false);
            LineRenderer.gameObject.SetActive(false);
            m_Text.text = "Finding Planes.....";
        }
    }

    private void UpdatePlacementPose()
    {
        var screenCenter = Camera.main.ViewportToScreenPoint(new Vector3(0.5f, 0.5f));
        var hits = new List<ARRaycastHit>();
        arRayManager.Raycast(screenCenter, hits, UnityEngine.XR.ARSubsystems.TrackableType.Planes);

        m_PlacementPoseIsValid = hits.Count > 0;
        if (m_PlacementPoseIsValid)
        {
            m_PlacementPose = hits[0].pose;
            var cameraForward = Camera.main.transform.forward;
            var cameraBearing = new Vector3(cameraForward.x, 0, cameraForward.z).normalized;
            m_PlacementPose.rotation = Quaternion.LookRotation(cameraBearing);
        }
    }

    // detect is this touch on the UI elements or Screen
    //private bool IsPointerOverUIObject()
    //{
    //    PointerEventData eventDataCurrentPosition = new PointerEventData(EventSystem.current);
    //    eventDataCurrentPosition.position = new Vector2(Input.mousePosition.x, Input.mousePosition.y);
    //    List<RaycastResult> results = new List<RaycastResult>();
    //    EventSystem.current.RaycastAll(eventDataCurrentPosition, results);
    //    return results.Count > 0;
    //}
}