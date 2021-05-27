using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

public class StarterSceneManager : MonoBehaviour
{

    [SerializeField] private GameObject triggerBallPrefab;

    [DllImport("__Internal")]
    public static extern int UnityHoloKit_GetRenderingMode();

    private void OnEnable()
    {
        int renderingMode = UnityHoloKit_GetRenderingMode();
        if (renderingMode != 2)
        {
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
        }

        //BoidMovementController.OnTriggerBallDisplayed += DisplayTriggerBall;
    }

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void DisplayTriggerBall()
    {
        Debug.Log("Trigger ball displayed.");

    }
}
