using UnityEngine;
using UnityEngine.XR.HoloKit;
using MLAPI;

public class TrackedHand : NetworkBehaviour
{
    private void Start()
    {
        if (IsOwner)
        {
            HoloKitHandTracking script = GameObject.Find("HoloKitHandTracking").GetComponent<HoloKitHandTracking>();
            script.HandCenter = this.gameObject;
        }
    }
}
