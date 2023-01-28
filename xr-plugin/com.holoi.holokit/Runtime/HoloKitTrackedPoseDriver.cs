using UnityEngine;
using Holoi.HoloKit.NativeInterface;

namespace Holoi.HoloKit
{
    public class HoloKitTrackedPoseDriver : MonoBehaviour
    {
        public bool IsActive
        {
            get => _isActive;
            set
            {
                _isActive = value;
            }
        }

        /// <summary>
        /// If this value is set to true, HoloKitTrackedPoseDriver will take control
        /// of the camera pose.
        /// </summary>
        private bool _isActive = false;

        private readonly Matrix4x4 RotationMatrix = Matrix4x4.Rotate(Quaternion.Euler(0f, 0f, -90f));

        private void Awake()
        {
            HoloKitARSessionManagerNativeInterface.OnARSessionUpdatedFrame += OnARSessionUpdatedFrame;
        }

        private void OnDestroy()
        {
            HoloKitARSessionManagerNativeInterface.OnARSessionUpdatedFrame -= OnARSessionUpdatedFrame;
        }

        private void OnARSessionUpdatedFrame(double timestamp, Matrix4x4 matrix)
        {
            if (_isActive)
            {
                matrix *= RotationMatrix;
                transform.SetPositionAndRotation(matrix.GetPosition(), matrix.rotation);
            }
        }
    }
}
