using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    public GameObject arCamera;
    public GameObject arOrigin;
    public Text rotation;
    public Text position;
    public Text qrCodePosition;

    private GameObject qrCode = null;

    // Update is called once per frame
    void Update()
    {
        rotation.text = arCamera.transform.rotation.ToString("F4");
        position.text = arCamera.transform.position.ToString("F4");

        if (qrCode == null)
        {
            qrCode = GameObject.FindGameObjectWithTag("qrcode");
        }
        else
        {
            qrCodePosition.text = qrCode.transform.position.ToString("F4");
        }
    }
}
