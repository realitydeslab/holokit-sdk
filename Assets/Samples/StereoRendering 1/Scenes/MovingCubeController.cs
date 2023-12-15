using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HoloKit
{
    public class MovingCubeController : MonoBehaviour
    {
        private void Update()
        {
            // Move the cube in sine wave
            transform.position = new Vector3(Mathf.Sin(Time.time) * 10, transform.position.y, transform.position.z);
        }
    }
}
