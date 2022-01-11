using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace UnityEngine.XR.HoloKit
{
    public class WatchConnectivityManager : MonoBehaviour
    {
        private static WatchConnectivityManager _instance;

        public static WatchConnectivityManager Instance { get { return _instance; } }

        //[DllImport("")]

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(this.gameObject);
            }
            else
            {
                _instance = this;
            }
        }
    }
}
