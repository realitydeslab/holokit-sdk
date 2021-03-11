using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Deactivate : MonoBehaviour
{
    private GameObject a;
    private static int frameCount = 0;

    // Start is called before the first frame update
    void Start()
    {
        a = GameObject.FindGameObjectWithTag("Landmark");
    }

    // Update is called once per frame
    void Update()
    {
        frameCount++;
        Debug.Log(frameCount);
        if(frameCount == 200)
        {
            a.SetActive(false);
        }
        if(frameCount == 300)
        {
            Debug.Log("re activate");
            a.SetActive(true);
        }
    }
}
