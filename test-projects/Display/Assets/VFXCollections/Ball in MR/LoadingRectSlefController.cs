using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

public class LoadingRectSlefController : MonoBehaviour
{
    public Transform Hand;
    [SerializeField] float m_InteractionRadius = 1;
    [SerializeField] float speed = 1;
    public float load = 0;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        if (Vector3.Distance(Hand.position, this.transform.position) < m_InteractionRadius)
        {
            load += Time.deltaTime * speed;
            if (load > 1) load = 1;
        }
        else
        {
            load -= Time.deltaTime * speed;
            if (load < 0) load = 0;
        }

        GetComponent<VisualEffect>().SetFloat("Loading", load);
    }
}
