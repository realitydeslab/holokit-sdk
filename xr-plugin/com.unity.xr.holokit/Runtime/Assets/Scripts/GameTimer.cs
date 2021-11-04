using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class GameTimer : MonoBehaviour
{

    [SerializeField]
    Text txt;

    private float m_StartTime;

    void Start()
    {
        m_StartTime = Time.time;
    }

    void Update()
    {
        float currentTime = Time.time - m_StartTime;
        //txt.text = currentTime.ToString("F2");

        string minutes = Mathf.Floor(currentTime / 60f).ToString("00");
        string seconds = (currentTime % 60f).ToString("00");
        txt.text = $"{minutes}:{seconds}";
    }
}
