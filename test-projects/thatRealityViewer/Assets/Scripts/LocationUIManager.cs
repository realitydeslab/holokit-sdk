using UnityEngine;
using UnityEngine.UI;

public class LocationUIManager : MonoBehaviour
{
    private Button m_InitLocationManagerButton;

    private Button m_StartUpdatingLocationButton;

    private Text m_LocationData;

    private void Start()
    {
        m_InitLocationManagerButton = transform.GetChild(0).GetComponent<Button>();
        m_InitLocationManagerButton.onClick.AddListener(InitLocationManager);

        m_StartUpdatingLocationButton = transform.GetChild(1).GetComponent<Button>();
        m_StartUpdatingLocationButton.onClick.AddListener(StartUpdatingLocation);

        m_LocationData = transform.GetChild(2).GetComponent<Text>();

        m_StartUpdatingLocationButton.gameObject.SetActive(false);
    }

    private void Update()
    {
        string newLocationData = $"Latitude: {LocationManager.Instance.CurrentLatitude}\n" +
            $"Longitude: {LocationManager.Instance.CurrentLongitude}\n" +
            $"Altitude: {LocationManager.Instance.CurrentAltitude}";
        m_LocationData.text = newLocationData;

    }

    private void InitLocationManager()
    {
        LocationManager.Instance.InitLocationManager();
        m_InitLocationManagerButton.gameObject.SetActive(false);
        m_StartUpdatingLocationButton.gameObject.SetActive(true);
    }

    private void StartUpdatingLocation()
    {
        LocationManager.Instance.StartUpdateLocation();
    }    
}
