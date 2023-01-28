using System.Collections.Generic;
using UnityEngine;
using Holoi.HoloKit.NativeInterface;

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

    public class HoloKitHandTracker : MonoBehaviour
    {
        public static HoloKitHandTracker Instance { get { return _instance; } }

        private static HoloKitHandTracker _instance;

        [SerializeField] private bool _enabled;

        [SerializeField] private bool _debugMode;

        public bool Enabled
        {
            get => _enabled;
            set
            {
                _enabled = value;
                HoloKitHandTrackerNativeInterface.SetHandTrackerEnabled(_enabled);
            }
        }

        public bool DebugMode
        {
            get => _debugMode;
            set
            {
                _debugMode = value;
                SetLandmarksVisible(value); 
            }
        }

        public int AvailableHandCount
        {
            get
            {
                int count = 0;
                foreach (var hand in _hands)
                {
                    if (hand.gameObject.activeSelf)
                    {
                        count++;
                    }
                }
                return count;
            }
        }

        public List<HoloKitHand> Hands => _hands;

        private readonly List<HoloKitHand> _hands = new();

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            else
            {
                _instance = this;
            }
        }

        private void Start()
        {
            for (int i = 0; i < transform.childCount; i++)
            {
                var child = transform.GetChild(i);
                if (child.TryGetComponent<HoloKitHand>(out var hand))
                {
                    _hands.Add(hand);
                }
            }

            HoloKitHandTrackerNativeInterface.OnHandPoseUpdated += OnHandPoseUpdated;
            HoloKitHandTrackerNativeInterface.RegisterHandTrackerDelegates();
            HoloKitHandTrackerNativeInterface.SetHandTrackerEnabled(_enabled);

            SetupLandmarksColor();
            SetLandmarksVisible(_debugMode);
        }

        private void OnDestroy()
        {
            HoloKitHandTrackerNativeInterface.SetHandTrackerEnabled(false);
            HoloKitHandTrackerNativeInterface.OnHandPoseUpdated -= OnHandPoseUpdated;
        }

        private void SetupLandmarksColor()
        {
            foreach (var hand in _hands)
            {
                for (int i = 0; i < HoloKitHand.MAX_LANDMARK_COUNT; i++)
                {
                    LandmarkType joint = (LandmarkType)i;
                    switch (joint)
                    {
                        case LandmarkType.Wrist:
                            hand.Landmarks[i].GetComponent<MeshRenderer>().material.color = Color.red;
                            break;
                        case LandmarkType.Thumb0:
                        case LandmarkType.Index0:
                        case LandmarkType.Middle0:
                        case LandmarkType.Ring0:
                        case LandmarkType.Little0:
                            hand.Landmarks[i].GetComponent<MeshRenderer>().material.color = Color.yellow;
                            break;
                        case LandmarkType.Thumb1:
                        case LandmarkType.Index1:
                        case LandmarkType.Middle1:
                        case LandmarkType.Ring1:
                        case LandmarkType.Little1:
                            hand.Landmarks[i].GetComponent<MeshRenderer>().material.color = Color.green;
                            break;
                        case LandmarkType.Thumb2:
                        case LandmarkType.Index2:
                        case LandmarkType.Middle2:
                        case LandmarkType.Ring2:
                        case LandmarkType.Little2:
                            hand.Landmarks[i].GetComponent<MeshRenderer>().material.color = Color.cyan;
                            break;
                        case LandmarkType.Thumb3:
                        case LandmarkType.Index3:
                        case LandmarkType.Middle3:
                        case LandmarkType.Ring3:
                        case LandmarkType.Little3:
                            hand.Landmarks[i].GetComponent<MeshRenderer>().material.color = Color.blue;
                            break;
                    }
                }
            }
        }

        private void SetLandmarksVisible(bool visible)
        {
            foreach (var hand in _hands)
            {
                for (int i = 0; i < HoloKitHand.MAX_LANDMARK_COUNT; i++)
                {
                    hand.Landmarks[i].GetComponent<MeshRenderer>().enabled = visible;
                }
            }
        }

        private void OnHandPoseUpdated(int handIndex, float[] poses)
        {
            HoloKitHand hand = _hands[handIndex];
            hand.LastUpdateTime = Time.time;
            if (!hand.gameObject.activeSelf)
            {
                hand.gameObject.SetActive(true);
            }
            for (int i = 0; i < HoloKitHand.MAX_LANDMARK_COUNT; i++) {
                hand.Landmarks[i].position = new Vector3(poses[i * 3], poses[i * 3 + 1], poses[i * 3 + 2]);
            }

        }
    }
}
