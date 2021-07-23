using System.Runtime.InteropServices;
using UnityEngine;

public class LocationManager : MonoBehaviour
{
    // This class is a singleton.
    private static LocationManager _instance;

    public static LocationManager Instance { get { return _instance; } }

    private double m_CurrentLatitude = 0;

    public double CurrentLatitude
    {
        get => m_CurrentLatitude;
    }

    private double m_CurrentLongitude = 0;

    public double CurrentLongitude
    {
        get => m_CurrentLongitude;
    }

    private double m_CurrentAltitude = 0;

    public double CurrentAltitude
    {
        get => m_CurrentAltitude;
    }

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_InitLocationManager();

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_StartUpdatingLocation();

    delegate void DidUpdateLocation(double latitude, double longitude, double altitude);
    [AOT.MonoPInvokeCallback(typeof(DidUpdateLocation))]
    static void OnDidUpdateLocation(double latitude, double longitude, double altitude)
    {
        Debug.Log($"[LocationManager]: did update location with latitude {latitude}, longitude {longitude} and altitude {altitude}");
        Instance.m_CurrentLatitude = latitude;
        Instance.m_CurrentLongitude = longitude;
        Instance.m_CurrentAltitude = altitude;
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetDidUpdateLocationDelegate(DidUpdateLocation callback);

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

    private void OnEnable()
    {
        UnityHoloKit_SetDidUpdateLocationDelegate(OnDidUpdateLocation);
    }

    public void InitLocationManager()
    {
        UnityHoloKit_InitLocationManager();
    }

    public void StartUpdateLocation()
    {
        UnityHoloKit_StartUpdatingLocation();
    }
}
