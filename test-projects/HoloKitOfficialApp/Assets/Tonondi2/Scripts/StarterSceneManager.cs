using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class StarterSceneManager : MonoBehaviour
{

    [SerializeField] private GameObject triggerBallPrefab;

    private void OnEnable()
    {
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
