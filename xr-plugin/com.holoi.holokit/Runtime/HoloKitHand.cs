using System.Collections.Generic;
using UnityEngine;

namespace Holoi.HoloKit
{
    public class HoloKitHand : MonoBehaviour
    {
        public List<Transform> Landmarks => _landmarks;

        public float LastUpdateTime
        {
            get => _lastUpdateTime;
            set
            {
                _lastUpdateTime = value;
            }
        }

        private readonly List<Transform> _landmarks = new();

        private float _lastUpdateTime;

        public const int MAX_LANDMARK_COUNT = 21;

        private const float DISAPPEAR_DELAY = 1f;

        private void Start()
        {
            for (int i = 0; i < MAX_LANDMARK_COUNT; i++)
            {
                _landmarks.Add(transform.GetChild(i));
            }
        }

        private void Update()
        {
            if (Time.time - _lastUpdateTime > DISAPPEAR_DELAY)
            {
                gameObject.SetActive(false);
            }
        }

        public Transform GetLandmark(LandmarkType landmarkType)
        {
            return _landmarks[(int)landmarkType];
        }
    }
}
