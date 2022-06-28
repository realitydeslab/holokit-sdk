using UnityEngine;
using HoloKit;

public class HoloKitController : MonoBehaviour
{
    private void Awake()
    {
        HoloKitARSessionControllerAPI.InterceptUnityARSessionDelegate();
    }
}
