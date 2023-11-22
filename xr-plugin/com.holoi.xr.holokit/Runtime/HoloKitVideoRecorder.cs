// SPDX-FileCopyrightText: Copyright 2023 Holo Interactive <dev@holoi.com>
// SPDX-FileContributor: Botao Amber Hu <botao@holoi.com>
// SPDX-License-Identifier: MIT

using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections.LowLevel.Unsafe;
using System; 
using System.Collections.Generic;
using UnityEngine.XR.ARFoundation;

namespace HoloKit {

    [RequireComponent(typeof(AudioListener))]
    [RequireComponent(typeof(ARCameraBackground))]
    [RequireComponent(typeof(Camera))]
    [RequireComponent(typeof(HoloKitCameraManager))]
    [RequireComponent(typeof(ARCameraManager))]
    public sealed class HoloKitVideoRecorder : MonoBehaviour
    {
        #region Editable attributes

        [SerializeField] Camera _recordCamera = null;

        #endregion

        #region Public properties and methods

        public bool IsRecording
        { get; private set; }

        public void StartRecording()
        {
             if (HoloKitCameraManager.Instance.RenderMode == HoloKitRenderMode.Stereo)
            {
                _recordCamera.GetComponent<ARCameraBackground>().enabled = true;
                _recordCamera.enabled = true;
            }

            var sampleRate = _recordMicrophone ? _audioDevice.sampleRate : 24000;
            var channelCount = _recordMicrophone ? _audioDevice.channelCount : 2;

            var path = PathUtil.GetTemporaryFilePath();
            HoloKitVideoRecorder_StartRecording(path, _source.width, _source.height, sampleRate, channelCount);
            _timeQueue.Clear();
            IsRecording = true;
        }

        public void StopRecording()
        {
            AsyncGPUReadback.WaitAllRequests();
            HoloKitVideoRecorder_EndRecording();
            IsRecording = false;
        }

        #endregion

        #region Private objects

        RenderTexture _buffer;
        TimeQueue _timeQueue = new TimeQueue();

        void ChangeSource(RenderTexture rt)
        {
            if (IsRecording)
            {
                Debug.LogError("Can't change the source while recording.");
                return;
            }

            if (_buffer != null) Destroy(_buffer);

            _source = rt;
            _buffer = new RenderTexture(rt.width, rt.height, 0);
        }

        #endregion

        #region Async GPU readback

        unsafe void OnSourceReadback(AsyncGPUReadbackRequest request)
        {
            if (!IsRecording) return;
            var data = request.GetData<byte>(0);
            var ptr = (IntPtr)NativeArrayUnsafeUtility.GetUnsafeReadOnlyPtr(data);
            AppendVideoFrame(ptr, (uint)data.Length, _timeQueue.Dequeue());
        }

        #endregion

        #region MonoBehaviour implementation

        void Start() {
            ChangeSource(_source);
            HoloKitCameraManager.OnHoloKitRenderModeChanged += OnHoloKitRenderModeChanged;
        }

        void OnDestroy()
        {
            if (IsRecording) {
                EndRecording();
            }
            Destroy(_buffer);
        }

        void Update()
        {
            if (!IsRecording) return;
            if (!_timeQueue.TryEnqueueNow()) return;
            Graphics.Blit(_source, _buffer, new Vector2(1, -1), new Vector2(0, 1));
            AsyncGPUReadback.Request(_buffer, 0, OnSourceReadback);
        }
        #endregion

        public void ToggleRecording()
        {
            if (IsRecording)
                StopRecording();
            else
                StartRecording();
        }


        [DllImport("__Internal", EntryPoint = "HoloKitVideoRecorder_StartRecording")]
        public static extern void StartRecording(string filePath, int width, int height, float sampleRate, int channelCount);

        [DllImport("__Internal", EntryPoint = "HoloKitVideoRecorder_AppendVideoFrame")]
        public static extern void AppendVideoFrame(IntPtr data, uint size, double time);

        [DllImport("__Internal", EntryPoint = "HoloKitVideoRecorder_AppendAudioFrame")]
        public static extern void AppendAudioFrame(IntPtr data, uint size, double time);

        [DllImport("__Internal", EntryPoint = "HoloKitVideoRecorder_EndRecording")]
        public static extern void EndRecording();
    }
}