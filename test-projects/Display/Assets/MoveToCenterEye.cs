using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveToCenterEye : MonoBehaviour
{

    [SerializeField]
    private GameObject obj;

    public GameObject arCamera;


    // Start is called before the first frame update
    void Start()
    {
        
        Vector3 translation = new Vector3 { x = 0.066945f, y = -0.02894f - 0.061695f, z = -0.07055f - 0.0091f };
        obj.transform.Translate(translation, Space.World);
    }

    // Update is called once per frame
    void Update()
    {
        Debug.Log($"ar camera position: {arCamera.transform.position}");
    }
}
