using System;
using UnityEngine;
using UnityEngine.XR.ARFoundation;

namespace HoloKit
{
    public struct HoloKitCameraData
    {
        public Rect LeftViewportRect;
        public Rect RightViewportRect;
        public float NearClipPlane;
        public float FarClipPlane;
        public Matrix4x4 LeftProjectionMatrix;
        public Matrix4x4 RightProjectionMatrix;
        public Vector3 CameraToCenterEyeOffset;
        public Vector3 CameraToScreenCenterOffset;
        public Vector3 CenterEyeToLeftEyeOffset;
        public Vector3 CenterEyeToRightEyeOffset;
        // The horizontal distance from the screen center in pixels
        public float AlignmentMarkerOffset;
    }

    public enum HoloKitRenderMode
    {
        Stereo = 0,
        Mono = 1
    }

    public class HoloKitCamera : MonoBehaviour
    {
        public static HoloKitCamera Instance { get { return _instance; } }

        private static HoloKitCamera _instance;

        public Transform CenterEyePose => _centerEyePose;

        [SerializeField] private Transform _centerEyePose;

        [SerializeField] private Camera _monoCamera;

        [SerializeField] private Camera _leftEyeCamera;

        [SerializeField] private Camera _rightEyeCamera;

        [SerializeField] private Camera _blackCamera;

        [SerializeField]
        [Range(0.054f, 0.074f)]
        private float _ipd = 0.064f;

        [SerializeField] private float _farClipPlane = 50f;

        [SerializeField] private HoloKitRenderMode _renderMode;

        public HoloKitRenderMode RenderMode
        {
            get => _renderMode;
            set
            {
                if (_renderMode != value)
                {
                    _renderMode = value;
                    ChangeRenderMode();
                    OnRenderModeChanged?.Invoke();
                }
            }
        }

        public float AlignmentMarkerOffset => _alignmentMarkerOffset;

        private float _alignmentMarkerOffset;

        private ARCameraBackground _arCameraBackground;

        public static event Action OnRenderModeChanged;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
            }
            else
            {
                _instance = this;
            }
            SetupHoloKitCameraData();
            _arCameraBackground = GetComponent<ARCameraBackground>();
            ChangeRenderMode();
        }

        private void SetupHoloKitCameraData()
        {
            HoloKitCameraData holokitCameraData = HoloKitOptics.GetHoloKitCameraData(
                HoloKitProfile.GetHoloKitModel(HoloKitType.HoloKitX),
                HoloKitProfile.GetPhoneModel(), _ipd, _farClipPlane);
            HoloKitCameraData holokitCameraData2 = HoloKitOpticsAPI.GetHoloKitCameraData(HoloKitType.HoloKitX, _ipd, _farClipPlane);
            Debug.Log($"LeftViewport: {holokitCameraData.LeftViewportRect} : {holokitCameraData2.LeftViewportRect}");
            Debug.Log($"RightViewport: {holokitCameraData.RightViewportRect} : {holokitCameraData2.RightViewportRect}");
            Debug.Log($"NearClipPlane: {holokitCameraData.NearClipPlane} : {holokitCameraData2.NearClipPlane}");
            Debug.Log($"FarClipPlane: {holokitCameraData.FarClipPlane} : {holokitCameraData2.FarClipPlane}");
            Debug.Log($"LeftProjectionMatrix: {holokitCameraData.LeftProjectionMatrix} : {holokitCameraData2.LeftProjectionMatrix}");
            Debug.Log($"RightProjectionMatrix: {holokitCameraData.RightProjectionMatrix} : {holokitCameraData2.RightProjectionMatrix}");
            Debug.Log($"CameraToCenterEyeOffset: {holokitCameraData.CameraToCenterEyeOffset} : {holokitCameraData2.CameraToCenterEyeOffset}");
            Debug.Log($"CameraToScreenCenterOffset: {holokitCameraData.CameraToScreenCenterOffset} : {holokitCameraData2.CameraToScreenCenterOffset}");
            Debug.Log($"CenterEyeToLeftEyeOffset: {holokitCameraData.CenterEyeToLeftEyeOffset} : {holokitCameraData2.CenterEyeToLeftEyeOffset}");
            Debug.Log($"CenterEyeToRightEyeOffset: {holokitCameraData.CenterEyeToRightEyeOffset} : {holokitCameraData2.CenterEyeToRightEyeOffset}");
            Debug.Log($"AlignmentMarkerOffset: {holokitCameraData.AlignmentMarkerOffset} : {holokitCameraData2.AlignmentMarkerOffset}");

            _centerEyePose.localPosition = holokitCameraData.CameraToCenterEyeOffset;
            _leftEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToLeftEyeOffset;
            _rightEyeCamera.transform.localPosition = holokitCameraData.CenterEyeToRightEyeOffset;

            // Setup left eye camera
            _leftEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            _leftEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            _leftEyeCamera.rect = holokitCameraData.LeftViewportRect;
            _leftEyeCamera.projectionMatrix = holokitCameraData.LeftProjectionMatrix;
            // Setup right eye camera
            _rightEyeCamera.nearClipPlane = holokitCameraData.NearClipPlane;
            _rightEyeCamera.farClipPlane = holokitCameraData.FarClipPlane;
            _rightEyeCamera.rect = holokitCameraData.RightViewportRect;
            _rightEyeCamera.projectionMatrix = holokitCameraData.RightProjectionMatrix;

            _alignmentMarkerOffset = holokitCameraData.AlignmentMarkerOffset;
        }

        private void ChangeRenderMode()
        {
            if (_renderMode == HoloKitRenderMode.Stereo)
            {
                _monoCamera.enabled = false;
                _arCameraBackground.enabled = false;
                _leftEyeCamera.gameObject.SetActive(true);
                _rightEyeCamera.gameObject.SetActive(true);
                _blackCamera.gameObject.SetActive(true);
            }
            else
            {
                _monoCamera.enabled = true;
                _arCameraBackground.enabled = true;
                _leftEyeCamera.gameObject.SetActive(false);
                _rightEyeCamera.gameObject.SetActive(false);
                _blackCamera.gameObject.SetActive(false);
            }
        }
    }
}
