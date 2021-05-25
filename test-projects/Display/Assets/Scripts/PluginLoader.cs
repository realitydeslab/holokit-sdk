using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public class PluginLoader : MonoBehaviour
{

    [DllImport("__Internal")]
    public static extern void UnityPluginLoadAtRuntime();

    private int count = 0;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        count++;
        if (count == 300)
        {
            UnityPluginLoadAtRuntime();
        }
    }
}
