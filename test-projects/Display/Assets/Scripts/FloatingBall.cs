using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using MLAPI;

public class FloatingBall : NetworkBehaviour
{

    [SerializeField] private float m_HandBouncingFactor = 0.15f;
    
    void Start()
    {
        // (0.00, -9.81, 0.00) as default
        //Debug.Log($"[FloatingBall]: current gravity is {Physics.gravity}");
        Physics.gravity = new Vector3(0f, -2f, 0f);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.tag.Equals("Meshing"))
        {
            //Debug.Log("Hit meshing");
            HittingRippleRoom.Instance.SetHitPoint(collision.contacts[0].point);
            return;
        }

        if (collision.gameObject.tag.Equals("HandSphere"))
        {
            Vector3 handSpherePosition = collision.transform.position;
            Vector3 direction = (transform.position - handSpherePosition).normalized;
            GetComponent<Rigidbody>().AddForce(direction * m_HandBouncingFactor);
        }

    }

}
