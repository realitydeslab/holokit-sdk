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

    private double m_CurrentTrueHeading = 0;

    public double CurrentTrueHeading
    {
        get => m_CurrentTrueHeading;
    }

    private double m_CurrentMagneticHeading = 0;

    public double CurrentMagneticHeading
    {
        get => m_CurrentMagneticHeading;
    }

    private double m_CurrentHeadingAccuracy = 0;

    public double CurrentHeadingAccuracy
    {
        get => m_CurrentHeadingAccuracy;
    }


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

    [DllImport("__Internal")]
    private static extern int UnityHoloKit_StartUpdatingHeading();

    delegate void DidUpdateHeading(double trueHeading, double magneticHeading, double headingAccuracy);
    [AOT.MonoPInvokeCallback(typeof(DidUpdateHeading))]
    static void OnDidUpdateHeading(double trueHeading, double magneticHeading, double headingAccuracy)
    {
        Debug.Log($"[LocationManager]: did update heading with true heading {trueHeading}, magnetic heading {magneticHeading} and heading accuracy {headingAccuracy}");
        Instance.m_CurrentTrueHeading = trueHeading;
        Instance.m_CurrentMagneticHeading = magneticHeading;
        Instance.m_CurrentHeadingAccuracy = headingAccuracy;
    }
    [DllImport("__Internal")]
    private static extern void UnityHoloKit_SetDidUpdateHeadingDelegate(DidUpdateHeading callback);

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
        UnityHoloKit_SetDidUpdateHeadingDelegate(OnDidUpdateHeading);
    }

    public void StartUpdatingLocation()
    {
        UnityHoloKit_StartUpdatingLocation();
    }

    public void StartUpdatingHeading()
    {
        UnityHoloKit_StartUpdatingHeading();
    }
}
