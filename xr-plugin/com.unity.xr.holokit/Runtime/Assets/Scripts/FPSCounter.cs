using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FPSCounter : MonoBehaviour
{
    public float m_refreshTime = 0.5f;
    int m_frameCounter = 0;
    float m_timeCounter = 0.0f;
    float m_lastFramerate = 0.0f;
    [SerializeField]
    Text txt;

    [SerializeField]
    [Tooltip("Sets the application's target frame rate.")]
    int m_TargetFrameRate = 120;

    public int targetFrameRate
    {
        get { return m_TargetFrameRate; }
        set
        {
            m_TargetFrameRate = value;
            SetFrameRate();
        }
    }

    void SetFrameRate()
    {
        Application.targetFrameRate = targetFrameRate;
    }

    void Start()
    {
        SetFrameRate();
    }

    void Update()
    {
        if (m_timeCounter < m_refreshTime)
        {
            m_timeCounter += Time.deltaTime;
            m_frameCounter++;
        }
        else
        {
            m_lastFramerate = (float)m_frameCounter / m_timeCounter;
            int lastfrInt = (int)m_lastFramerate;

            if (txt != null)
            {
                txt.text = lastfrInt.ToString();
            }
            m_frameCounter = 0;
            m_timeCounter = 0.0f;

        }
    }
}