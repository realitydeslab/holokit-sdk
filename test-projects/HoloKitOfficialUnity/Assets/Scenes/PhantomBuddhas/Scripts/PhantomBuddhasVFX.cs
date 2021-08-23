using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class PhantomBuddhasVFX : MonoBehaviour
{

    VisualEffect vfx;
    void Start()
    {
        vfx = GetComponent<VisualEffect>();
        
    }

    
    void Update()
    {
        GameObject[] go = GameObject.FindGameObjectsWithTag("TrackedHand");
        if (go.Length == 0) Debug.Log("no hand found for vfx effect");

        for (int i = 0; i < go.Length; i++)
        {
            vfx.SetVector3("HandCenter" + i, go[i].transform.position);
        }
    }
}
