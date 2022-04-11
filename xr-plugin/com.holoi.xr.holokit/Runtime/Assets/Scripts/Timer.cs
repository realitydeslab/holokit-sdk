using UnityEngine.UI;

namespace UnityEngine.XR.HoloKit
{
    internal class Timer : MonoBehaviour
    {
        [SerializeField]
        private Text _text;

        private float _startTime;

        private void Start()
        {
            _startTime = Time.time;
        }

        private void Update()
        {
            float timeToDisplay = Time.time - _startTime;
            float minutes = Mathf.FloorToInt(timeToDisplay / 60);
            float seconds = Mathf.FloorToInt(timeToDisplay % 60);
            _text.text = string.Format("{0:00}:{1:00}", minutes, seconds);
        }
    }
}