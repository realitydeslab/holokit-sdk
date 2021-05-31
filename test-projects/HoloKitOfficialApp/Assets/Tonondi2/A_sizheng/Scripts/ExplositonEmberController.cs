using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ExplositonEmberController : MonoBehaviour
{
    public MeshRenderer MeshingRenderer;
    public int posSum = 3;
    public Vector3[] positions;
    public float[] triggerTime;
    public bool[] isEmpty;

    // Start is called before the first frame update
    void Awake()
    {
        positions = new Vector3[posSum];
        triggerTime = new float[posSum];
        isEmpty = new bool[posSum];

        for (int i = 0; i < posSum; i++)
        {
            positions[i] = new Vector3(999, 999, 999);
            triggerTime[i] = 0;
            isEmpty[i] = true;
        }
    }

    private void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        for (int i = 0; i < posSum; i++)
        {
            if (!isEmpty[i])
            {
                //Debug.Log("setimpacts");
                float impact = Time.time - triggerTime[i];
                Shader.SetGlobalFloat("Impact_" + i, impact);
                if (impact > 9) isEmpty[i] = true;

                //Debug.Log("setpositions");
                Shader.SetGlobalVector("Position_" + i, positions[i]);
            }
            else { }
        }
    }
}
