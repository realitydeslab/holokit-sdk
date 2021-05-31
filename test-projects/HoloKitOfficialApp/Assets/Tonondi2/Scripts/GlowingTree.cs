using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GlowingTree : MonoBehaviour
{
 
    public Transform Hand;

    private float growLerp = 0;
    [SerializeField]
    private float speed = 1;

    public bool growOrDecal = true;
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        GetComponent<MeshRenderer>().material.SetVector("_Hand", Hand.position);

        if (growOrDecal)
        {
            growLerp += Time.deltaTime * speed;
            if (growLerp >= 1) growLerp = 1;

        }
        else
        {
            growLerp -= Time.deltaTime * speed;
            if (growLerp <= 0) growLerp = 0;
        }

        GetComponent<MeshRenderer>().material.SetFloat("_Growth_Lerp", growLerp);
    }
}
