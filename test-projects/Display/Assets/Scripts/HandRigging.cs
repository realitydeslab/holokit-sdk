using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HandRigging : MonoBehaviour
{
    [SerializeField] private Transform landmarkWrist;

    private void FixedUpdate()
    {
        transform.position = landmarkWrist.position;
    }
}
