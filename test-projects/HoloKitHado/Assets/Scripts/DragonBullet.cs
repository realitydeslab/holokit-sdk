using UnityEngine;
using MLAPI;
using MLAPI.NetworkVariable;

public class DragonBullet : NetworkBehaviour
{
    public NetworkVariableVector3 InitialForce = new NetworkVariableVector3(new NetworkVariableSettings
    {
        WritePermission = NetworkVariablePermission.OwnerOnly,
        ReadPermission = NetworkVariablePermission.Everyone
    }, Vector3.zero);

    private void Start()
    {
        GetComponent<Rigidbody>().AddForce(InitialForce.Value);
    }

    private void Update()
    {
        if (!IsServer) { return; }

        if (Vector3.Distance(transform.position, Vector3.zero) > 30f)
        {
            // Detroy the bullet which is too far away from the battle field.
            Destroy(gameObject);
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if(!IsServer) { return; }

        if (other.tag.Equals("Shield"))
        {
            Destroy(gameObject);
        }
    }
}
