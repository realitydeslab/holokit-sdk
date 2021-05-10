using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public class Callback : MonoBehaviour
{

    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetDelegate(DelegateMessage callback);

    delegate void DelegateMessage(int number);

    [AOT.MonoPInvokeCallback(typeof(DelegateMessage))]
    static void DelegateMessageReceived(int number)
    {
        Debug.Log("The fucking callback function is successfully called, the received number is: " + number);
    }

    public static void InitializeDelegate()
    {
        UnityHoloKit_SetDelegate(DelegateMessageReceived);
    }

    private void Start()
    {
        InitializeDelegate();
    }
}
