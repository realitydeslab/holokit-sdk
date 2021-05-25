using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public class ProjectionMatrixSync : MonoBehaviour
{
    [DllImport("__Internal")]
    public static extern void UnityHoloKit_SetUnityProjectionMatrix(float[] column0, float[] column1, float[] column2, float[] column3);

    // Start is called before the first frame update
    void Start()
    {
        var projectionMatrix = Camera.main.projectionMatrix;
        float[] column0 = { projectionMatrix.GetColumn(0).x, projectionMatrix.GetColumn(0).y, projectionMatrix.GetColumn(0).z, projectionMatrix.GetColumn(0).w };
        float[] column1 = { projectionMatrix.GetColumn(1).x, projectionMatrix.GetColumn(1).y, projectionMatrix.GetColumn(1).z, projectionMatrix.GetColumn(1).w };
        float[] column2 = { projectionMatrix.GetColumn(2).x, projectionMatrix.GetColumn(2).y, projectionMatrix.GetColumn(2).z, projectionMatrix.GetColumn(2).w };
        float[] column3 = { projectionMatrix.GetColumn(3).x, projectionMatrix.GetColumn(3).y, projectionMatrix.GetColumn(3).z, projectionMatrix.GetColumn(3).w };
        UnityHoloKit_SetUnityProjectionMatrix(column0, column1, column2, column3);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
