using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InteractiveCube : MonoBehaviour
{
    [SerializeField] private GameObject leftHandLandmark;
    [SerializeField] private GameObject rightHandLandmark;

    private float speed = 0.05f;

    private const float kMinDistance = 0.08f;

    public enum InteractiveCubeState { idle, telekinesis };

    private InteractiveCubeState currentState = InteractiveCubeState.idle;

    private void OnEnable()
    {
        UnityEngine.XR.HoloKit.HandTracking.OnChangedToBloom += StartTelekinesis;
        UnityEngine.XR.HoloKit.HandTracking.OnChangedToNone += StopTelekinesis;
    }

    private void OnDisable()
    {
        UnityEngine.XR.HoloKit.HandTracking.OnChangedToBloom -= StartTelekinesis;
        UnityEngine.XR.HoloKit.HandTracking.OnChangedToNone -= StopTelekinesis;
    }

    void StartTelekinesis()
    {
        currentState = InteractiveCubeState.telekinesis;
    }

    void StopTelekinesis()
    {
        currentState = InteractiveCubeState.idle;
    }

    private void FixedUpdate()
    {
        if (Vector3.Distance(transform.position, leftHandLandmark.transform.position) < kMinDistance)
        {
            GetComponent<Rigidbody>().velocity = Vector3.zero;
            return;
        }
        if (currentState == InteractiveCubeState.telekinesis)
        {
            Vector3 direction = (leftHandLandmark.transform.position - transform.position).normalized;
            GetComponent<Rigidbody>().velocity += direction * speed;
        }
        else
        {
            GetComponent<Rigidbody>().velocity = Vector3.zero;
        }
    }
}
