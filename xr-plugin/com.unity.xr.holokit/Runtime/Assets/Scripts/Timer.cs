using UnityEngine.UI;

namespace UnityEngine.XR.HoloKit
{
    public class Timer : MonoBehaviour
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
            string minutes = Mathf.Floor(currentTime / 60f).ToString("00");
            string seconds = (currentTime % 60f).ToString("00");
            txt.text = $"{minutes}:{seconds}";
        }
    }
}