using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class DisturbStripe : MonoBehaviour
{
    [Range(0.0f, 1.0f)]
    public float ScaleForBoom = 0f;
    public float explosionForceMultipier = 1;
    bool boomable = true;

    public Transform Hand;
    public float Radius;



    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        GetComponent<VisualEffect>().SetFloat("ScaleForBoom", ScaleForBoom);

        if(ScaleForBoom == 1 && boomable)
        {
            GetComponent<VisualEffect>().SendEvent("OnExplode");
            ShootEmbers();
            boomable = false;
        }
        if(!boomable && ScaleForBoom == 0)
        {
            boomable = true;
            ResetEmbers();
        }


        // trigger condition:
        if (Vector3.Distance(Hand.position, this.transform.position) < Radius)
        {
            ScaleForBoom += Time.deltaTime * 0.5f;
            if (ScaleForBoom >= 1) ScaleForBoom = 1;
        }
        else
        {
            ScaleForBoom -= Time.deltaTime * 0.5f;
            if (ScaleForBoom <= 0) ScaleForBoom = 0;
        }

    }

    void ShootEmbers() 
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            float x = Random.Range(-1, 1);
            float y = Random.Range(0, 1);
            float z = Random.Range(-1, 1);
            Vector3 velocity = new Vector3(x,y,z) * explosionForceMultipier;
            transform.GetChild(i).GetComponent<Rigidbody>().isKinematic = false;
            transform.GetChild(i).GetComponent<Rigidbody>().velocity = velocity;
        }
    }

    void ResetEmbers()
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            transform.GetChild(i).GetComponent<Rigidbody>().isKinematic = true;
            transform.GetChild(i).localPosition = Vector3.zero;

        }
    }
}
