using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using Holoi.HoloKit.NativeInterface;

namespace Holoi.HoloKit
{
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
                SetHandTrackerEnabledInternal(_enabled);
            }
        }

        public bool DebugMode
        {
            get => _debugMode;
            set
            {
                _debugMode = value;
                SetHandsVisible(value); 
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
            if (!HoloKitDeviceProfile.SupportsLiDAR())
            {
                Debug.LogError("[HoloKitSDK] The current device doesn't support hand tracking since it doesn't have LiDAR sensor");
                return;
            }

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
            SetHandTrackerEnabledInternal(_enabled);

            SetHandsVisible(_debugMode);
        }

        private void OnDestroy()
        {
            HoloKitHandTrackerNativeInterface.SetHandTrackerEnabled(false);
            HoloKitHandTrackerNativeInterface.OnHandPoseUpdated -= OnHandPoseUpdated;
        }

        private void SetHandTrackerEnabledInternal(bool enabled)
        {
            if (enabled)
            {
                var arOcclusionManager = FindObjectOfType<AROcclusionManager>();
                if (arOcclusionManager == null || arOcclusionManager.enabled == false)
                {
                    Debug.LogError("[HoloKitSDK] You must have an AROcclusionManager before turn on hand tracking");
                    return;
                }
            }

            HoloKitHandTrackerNativeInterface.SetHandTrackerEnabled(_enabled);
        }

        private void SetHandsVisible(bool visible)
        {
            foreach (var hand in _hands)
            {
                hand.SetLandmarksVisible(visible);
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
