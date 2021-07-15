using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PetalSelfControl : MonoBehaviour
{
    [SerializeField]
    private float m_ExplodePower = 1;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }

    private void OnMouseDown()
    {
        OnExplode();
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.gameObject.tag == "AttackBall")
        {

        }
    }

    public  void OnExplode()
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            transform.GetChild(i).GetComponent<Rigidbody>().AddExplosionForce(m_ExplodePower, transform.position, 1, 0, ForceMode.Impulse);
        }
        this.transform.parent = null;

        WaitAndKill(3);
    }

    IEnumerator WaitAndKill(float t )
    {
        yield return new WaitForSeconds(3);
        Destroy(this.transform.gameObject);
    }
}
