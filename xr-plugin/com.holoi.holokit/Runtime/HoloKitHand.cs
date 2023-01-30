using System.Collections.Generic;
using UnityEngine;
using Holoi.HoloKit.Utils;

namespace Holoi.HoloKit
{
    public enum LandmarkType
    {
        Wrist = 0,
        Thumb0 = 1,
        Thumb1 = 2,
        Thumb2 = 3,
        Thumb3 = 4,
        Index0 = 5,
        Index1 = 6,
        Index2 = 7,
        Index3 = 8,
        Middle0 = 9,
        Middle1 = 10,
        Middle2 = 11,
        Middle3 = 12,
        Ring0 = 13,
        Ring1 = 14,
        Ring2 = 15,
        Ring3 = 16,
        Little0 = 17,
        Little1 = 18,
        Little2 = 19,
        Little3 = 20
    }

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

        private const float DISAPPEAR_DELAY = 0.2f;

        private void Awake()
        {
            for (int i = 0; i < MAX_LANDMARK_COUNT; i++)
            {
                _landmarks.Add(transform.GetChild(i));
            }
        }

        private void Start()
        {
            SetupLandmarksColor();

            if (PlatformChecker.IsRuntime)
                gameObject.SetActive(false);
        }

        private void Update()
        {
            if (Time.time - _lastUpdateTime > DISAPPEAR_DELAY)
            {
                if (PlatformChecker.IsRuntime)
                    gameObject.SetActive(false);
            }
        }

        public Vector3 GetLandmarkPosition(LandmarkType landmarkType)
        {
            return _landmarks[(int)landmarkType].position;
        }

        private void SetupLandmarksColor()
        {
            for (int i = 0; i < MAX_LANDMARK_COUNT; i++)
            {
                LandmarkType joint = (LandmarkType)i;
                switch (joint)
                {
                    case LandmarkType.Wrist:
                        _landmarks[i].GetComponent<MeshRenderer>().material.color = Color.red;
                        break;
                    case LandmarkType.Thumb0:
                    case LandmarkType.Index0:
                    case LandmarkType.Middle0:
                    case LandmarkType.Ring0:
                    case LandmarkType.Little0:
                        _landmarks[i].GetComponent<MeshRenderer>().material.color = Color.yellow;
                        break;
                    case LandmarkType.Thumb1:
                    case LandmarkType.Index1:
                    case LandmarkType.Middle1:
                    case LandmarkType.Ring1:
                    case LandmarkType.Little1:
                        _landmarks[i].GetComponent<MeshRenderer>().material.color = Color.green;
                        break;
                    case LandmarkType.Thumb2:
                    case LandmarkType.Index2:
                    case LandmarkType.Middle2:
                    case LandmarkType.Ring2:
                    case LandmarkType.Little2:
                        _landmarks[i].GetComponent<MeshRenderer>().material.color = Color.cyan;
                        break;
                    case LandmarkType.Thumb3:
                    case LandmarkType.Index3:
                    case LandmarkType.Middle3:
                    case LandmarkType.Ring3:
                    case LandmarkType.Little3:
                        _landmarks[i].GetComponent<MeshRenderer>().material.color = Color.blue;
                        break;
                }
            }
        }

        public void SetLandmarksVisible(bool visible)
        {
            for (int i = 0; i < MAX_LANDMARK_COUNT; i++)
            {
                _landmarks[i].GetComponent<MeshRenderer>().enabled = visible;
            }
        }
    }
}
