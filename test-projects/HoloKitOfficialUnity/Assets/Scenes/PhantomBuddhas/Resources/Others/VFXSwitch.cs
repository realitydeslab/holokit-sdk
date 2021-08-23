using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class VFXSwitch : MonoBehaviour
{

    private VisualEffect visualEffect;

    public Texture SDFTeapot;
    public Texture DGTeapot;
    public Texture SDFHead;
    public Texture DGHead;

    private bool isTeapot = true;

    private int switchInterval = 0;

    // Start is called before the first frame update
    void Start()
    {
        visualEffect = GetComponent<VisualEffect>();
    }

    // Update is called once per frame
    void Update()
    {
        switchInterval++;
    }

    private void OnTriggerEnter(Collider col)
    {
        if(switchInterval < 100)
        {
            return;
        }
        switchInterval = 0;

        if (isTeapot)
        {
            visualEffect.SetTexture("Signed Distance Field", SDFHead);
            visualEffect.SetTexture("Distance Gradient", DGHead);
            isTeapot = false;
        }
        else
        {
            visualEffect.SetTexture("Signed Distance Field", SDFTeapot);
            visualEffect.SetTexture("Distance Gradient", DGTeapot);
            isTeapot = true;
        }
    }
}
