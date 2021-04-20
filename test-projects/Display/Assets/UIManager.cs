using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    public GameObject arCamera;
    public Text rotation;
    public Text position;

    // Update is called once per frame
    void Update()
    {
        rotation.text = arCamera.transform.rotation.ToString();
        position.text = arCamera.transform.position.ToString();
    }
}
