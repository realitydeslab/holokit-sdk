using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using UnityEngine;

public class SetTargetFrameRate: MonoBehaviour
{
    void Start()
    {
        // Make the game run as fast as possible
        Application.targetFrameRate = 60;
    }
}