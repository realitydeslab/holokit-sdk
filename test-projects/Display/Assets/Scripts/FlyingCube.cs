using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;

public class FlyingCube : NetworkBehaviour
{
    private Vector3 m_CenterPosition;

    private void Start()
    {
        m_CenterPosition = transform.position;
    }

    void Update()
    {
        if (IsServer) { return; }
        float theta = Time.frameCount / 10.0f;
        transform.position = m_CenterPosition + new Vector3((float)System.Math.Cos(theta), 0.0f, (float)System.Math.Sin(theta));
    }
}
