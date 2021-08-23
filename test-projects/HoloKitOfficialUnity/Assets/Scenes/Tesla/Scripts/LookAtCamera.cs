using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class LookAtCamera : MonoBehaviour
{
    VisualEffect vfx;
    private IEnumerator coroutine;

    void Start()
    {
        vfx = GetComponent<VisualEffect>();

    }

    void Update()
    {
        transform.LookAt(Camera.main.transform.position);
    }

    public void OnTrigger()
    {
        vfx.SetFloat("Size", 0.01f);
        coroutine = RecoverSize(2.0f);
        StartCoroutine(coroutine);
    }
    IEnumerator RecoverSize(float waitTime)
    {
        yield return new WaitForSeconds(waitTime);
        vfx.SetFloat("Size", 0.03f);

    }
}
