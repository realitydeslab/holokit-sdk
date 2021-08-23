using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class VFXLineRenderer : MonoBehaviour
{
    VisualEffect vfx;
    ARTapToPlaceObject ATTO;

    [SerializeField] Vector3 offset;
    // Start is called before the first frame update
    void Start()
    {
         ATTO = FindObjectOfType<ARTapToPlaceObject>();
         vfx= GetComponent<VisualEffect>();
    }

    // Update is called once per frame
    void Update()
    {
        if(Camera.main != null) transform.position = Camera.main.transform.position + offset;

        if (ATTO.PlacementPoseIsValid)
        {
            if (vfx.enabled == false) vfx.enabled = true;
            //vfx.SetVector3("Position_position",Camera.main.transform.position);
            vfx.SetVector3("TargetPosition_position", ATTO.PlacementPose.position - transform.position);
            Debug.Log("sample line vfx position:" + ATTO.PlacementPose.position);
        }
        else
        {
            if (vfx.enabled) vfx.enabled = false;
            Debug.Log("PlacementPoseIsNotValid, kill the Sample Line VFX");
        }
    }
}