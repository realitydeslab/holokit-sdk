using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;

public class CollaborationManager : MonoBehaviour
{
    void OnEnable()
    {
        ARSession session = FindObjectOfType<ARSession>();
        ARKitSessionSubsystem subsystem = session.subsystem as ARKitSessionSubsystem;
        subsystem.collaborationRequested = true;
    }
}
