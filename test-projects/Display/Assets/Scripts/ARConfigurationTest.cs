using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;

public class ARConfigurationTest : MonoBehaviour
{
    private AROcclusionManager occlusionManager;

    // Start is called before the first frame update
    void Start()
    {
        occlusionManager = GetComponent<AROcclusionManager>();
        Debug.Log($"[ARConfigurationTest]: current environment depth mode: {occlusionManager.currentEnvironmentDepthMode}");
        //occlusionManager.requestedEnvironmentDepthMode = UnityEngine.XR.ARSubsystems.EnvironmentDepthMode.Fastest;
        //occlusionManager.requestedHumanDepthMode = UnityEngine.XR.ARSubsystems.HumanSegmentationDepthMode.Best;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
