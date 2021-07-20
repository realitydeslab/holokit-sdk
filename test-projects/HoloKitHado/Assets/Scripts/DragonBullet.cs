using UnityEngine;
using MLAPI;

public class DragonBullet : NetworkBehaviour
{
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
