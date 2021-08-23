using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;
using UnityEngine.XR.ARFoundation;
using UnityEngine.Events;
using MLAPI;
using MLAPI.Connection;

public class MenuSimple : MonoBehaviour
{
    [Range(0, 1)]
    public float loading = 0;
    //public Transform hand;
    [SerializeField]
    private float m_interactRadius = 1f;
    [SerializeField]
    private float loadSpeed = 1f;

    public OnClickedEvent onCustomEvent;
    public void OnCustomCallBack()
    {
        Debug.Log("触发自定义事件");
    }

    public void TriggerCustomEvent()
    {
        Debug.Log("尝试触发自定义事件");
        onCustomEvent?.Invoke();
    }

    void Start()
    {

    }

    void Update()
    {
        if (FindObjectOfType<ARTapToPlaceObject>().PlacementPoseIsValid)
        {
            LoadingValue();
        }
        transform.GetComponent<VisualEffect>().SetFloat("Loading", loading);

        if (loading == 1)
        {
            //TriggerCustomEvent();
            var script = GetPlayerScript(NetworkManager.Singleton.ServerClientId);
            script.SpawnTesla();
            this.gameObject.SetActive(false);
        }
    }

    void LoadingValue()
    {
        var handposition = FindObjectOfType<UnityEngine.XR.HoloKit.HoloKitHandMovementManager>().transform.position;
        if(handposition == null)
        {
            Debug.LogError("Not find handpositon of MenuSimple");
            return;
        }
        else
        {
            if (Vector3.Distance(handposition, this.transform.position) < m_interactRadius)
            {
                loading += Time.deltaTime * loadSpeed;
                if (loading > 1) loading = 1;
            }
            else
            {
                loading -= Time.deltaTime * loadSpeed;
                if (loading < 0) loading = 0;
            }
        }

    }

    private TeslaPlayer GetPlayerScript(ulong clientId)
    {
        if (!NetworkManager.Singleton.ConnectedClients.TryGetValue(clientId, out NetworkClient networkClient))
        {
            return null;
        }

        if (!networkClient.PlayerObject.TryGetComponent<TeslaPlayer>(out TeslaPlayer script))
        {
            return null;
        }
        return script;
    }
}


[Serializable]
public class OnClickedEvent : UnityEvent { }