using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NewBehaviourScript : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
     
        UnloadImportedDll("");
    }
    public static void UnloadImportedDll(string DllPath)
    {
        foreach (System.Diagnostics.ProcessModule mod in System.Diagnostics.Process.GetCurrentProcess().Modules)
        {
            Debug.Log(mod.FileName);
            if (mod.FileName == DllPath)
            {
                Debug.Log(mod.FileName);
                //FreeLibrary(mod.BaseAddress);
            }
        }
    }

}
