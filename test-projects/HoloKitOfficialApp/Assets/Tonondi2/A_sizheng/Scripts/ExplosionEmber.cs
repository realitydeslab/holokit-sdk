using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ExplosionEmber : MonoBehaviour
{
    ExplositonEmberController parent;
    // Start is called before the first frame update
    void Start()
    {
        parent = transform.parent.GetComponent<ExplositonEmberController>();
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void FixedUpdate()
    {

    }

    private void OnTriggerEnter(Collider other)
    {
        if(other.tag == "Meshing")
        {
            parent.GetComponent<ExplositonEmberController>().MeshingRenderer = other.GetComponent<MeshRenderer>();
            int i = 0;
            while (i < parent.posSum)
            {
                if (parent.isEmpty[i]) // find a empty pos and add the current pos;
                {
                    parent.positions[i] = transform.position;
                    parent.triggerTime[i] = Time.time;
                    parent.isEmpty[i] = false;
                    break;
                }
                i++;
            }
        }
    }
}
