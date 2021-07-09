using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;
using System.Linq;
using MLAPI;

namespace UnityEngine.XR.HoloKit
{
    public class HoloKitHandTracking : MonoBehaviour
    {

        private float k_MaxHandDepth = 1.0f;

        public ComputeShader m_ComputeShader;

        private Camera m_ARCamera;
        private AROcclusionManager m_OcclusionManager;
        private ARCameraManager m_ARCameraManager;

        [SerializeField] private bool m_HandTrackingEnabled = true;

        private bool m_IsHandValid = false;

        [SerializeField] public GameObject m_HandCenter;

        private int m_InitializeHorizonalHistogramKernel;
        private int m_InitializeVerticalHistogramKernel;
        private int m_CalculateHistogramKernel;

        private ComputeBuffer m_VerticalHistogramBuffer;
        private ComputeBuffer m_HorizonalHistogramBuffer;
        private uint[] m_VerticalHistogramData;
        private uint[] m_HorizonalHistogramData;

        private int m_Width = 0;
        private int m_Height = 0;

        private void Start()
        {
            m_ARCameraManager = GameObject.FindObjectOfType<ARCameraManager>();
            m_ARCamera = m_ARCameraManager.GetComponent<Camera>();
            m_OcclusionManager = GameObject.FindObjectOfType<AROcclusionManager>();

            Debug.Assert(m_ComputeShader != null);
            Debug.Assert(m_OcclusionManager != null);
            Debug.Assert(m_ARCamera != null);

            m_HorizonalHistogramBuffer = null;
            m_VerticalHistogramBuffer = null;
            m_Width = 0;
            m_Height = 0;

            m_InitializeHorizonalHistogramKernel = m_ComputeShader.FindKernel("InitializeHorizonalHistogram");
            m_InitializeVerticalHistogramKernel = m_ComputeShader.FindKernel("InitializeVerticalHistogram");
            m_CalculateHistogramKernel = m_ComputeShader.FindKernel("CalculateHistogram");

            m_ComputeShader.SetFloat("MaxDepth", k_MaxHandDepth);
        }

        struct HistStruct
        {
            public uint sum;
        }

        private void Update()
        {
            if (m_HandCenter == null) return;

            if (m_InitializeHorizonalHistogramKernel >= 0 &&
                m_InitializeVerticalHistogramKernel >= 0 &&
                m_CalculateHistogramKernel >= 0 &&
                m_OcclusionManager.humanDepthTexture != null && m_OcclusionManager.humanStencilTexture != null)
            {
                if (m_Width == 0 || m_Height == 0)
                {
                    m_Width = m_OcclusionManager.humanDepthTexture.width;
                    m_Height = m_OcclusionManager.humanDepthTexture.height;
                    // Debug.Log($"Update Holokit Hand Tracking with humanDepthTexture.width={m_Width} humanDepthTexture.height={m_Height}");
                    // Debug.Log($"Update Holokit Hand Tracking with m_OcclusionManager.humanStencilTexture={m_OcclusionManager.humanStencilTexture.width} m_OcclusionManager.humanStencilTexture={m_OcclusionManager.humanStencilTexture.height}");

                    m_HorizonalHistogramBuffer = new ComputeBuffer(m_Width, sizeof(uint));
                    m_VerticalHistogramBuffer = new ComputeBuffer(m_Height, sizeof(uint));
                    m_HorizonalHistogramData = new uint[m_Width];
                    m_VerticalHistogramData = new uint[m_Height];
                    m_ComputeShader.SetBuffer(m_InitializeHorizonalHistogramKernel, "HorizonalHistogram", m_HorizonalHistogramBuffer);
                    m_ComputeShader.SetBuffer(m_InitializeVerticalHistogramKernel, "VerticalHistogram", m_VerticalHistogramBuffer);
                    m_ComputeShader.SetBuffer(m_CalculateHistogramKernel, "HorizonalHistogram", m_HorizonalHistogramBuffer);
                    m_ComputeShader.SetBuffer(m_CalculateHistogramKernel, "VerticalHistogram", m_VerticalHistogramBuffer);
                }

                m_ComputeShader.Dispatch(m_InitializeHorizonalHistogramKernel, Mathf.CeilToInt(m_Width / 64f), 1, 1);
                m_ComputeShader.Dispatch(m_InitializeVerticalHistogramKernel, Mathf.CeilToInt(m_Height / 64f), 1, 1);

                m_ComputeShader.SetTexture(m_CalculateHistogramKernel, "DepthTexture", m_OcclusionManager.humanDepthTexture);
                m_ComputeShader.SetTexture(m_CalculateHistogramKernel, "StencilTexture", m_OcclusionManager.humanStencilTexture);
                m_ComputeShader.Dispatch(m_CalculateHistogramKernel, Mathf.CeilToInt(m_Width / 8f), Mathf.CeilToInt(m_Height / 8f), 1);

                m_HorizonalHistogramBuffer.GetData(m_HorizonalHistogramData);
                m_VerticalHistogramBuffer.GetData(m_VerticalHistogramData);

                float xCoordinate = m_HorizonalHistogramData.Select((x, i) => new { weightedX = (float)x * (m_Width - i) / m_Width, i }).Aggregate((a, a1) => a.weightedX > a1.weightedX ? a : a1).i; //Friendly for Right Hand
                float yCoordinate = m_Height - m_VerticalHistogramData.Select((x, i) => new { weightedX = (float)x * (m_Height - i) / m_Height, i }).Aggregate((a, a1) => a.weightedX > a1.weightedX ? a : a1).i;
                float xCoordinateInCamera = xCoordinate / m_Width * m_ARCamera.pixelWidth;
                float yCoordinateInCamera = yCoordinate / m_Height * m_ARCamera.pixelHeight;
                float zCoordinateInCamera = 0.4f;

                float moreThanThresholdX = m_HorizonalHistogramData.Where(x => x > 10).Count();
                float moreThanThresholdY = m_VerticalHistogramData.Where(x => x > 10).Count();

                m_IsHandValid = moreThanThresholdX / m_Width > 0.05f && moreThanThresholdY / m_Height > 0.05f;
                //Debug.Log($"Update xCoordinate={xCoordinate} yCoordinate={yCoordinate} moreThanThresholdX={moreThanThresholdX} moreThanThresholdY={moreThanThresholdY}");

                if (m_IsHandValid)
                {
                    m_HandCenter.SetActive(true);
                    m_HandCenter.transform.position = m_ARCamera.ScreenToWorldPoint(new Vector3(xCoordinateInCamera, yCoordinateInCamera, zCoordinateInCamera));
                }
                else
                {
                    //m_HandCenter.SetActive(false);
                    //m_HandCenter.transform.position = new Vector3(0f, 100f, 0f);
                    m_HandCenter.transform.position = m_ARCamera.transform.position;
                }
            }
            else
            {
                //m_HandCenter.SetActive(false);
                //m_HandCenter.transform.position = new Vector3(0f, 100f, 0f);
                m_HandCenter.transform.position = m_ARCamera.transform.position;
                m_IsHandValid = false;
            }
        }

        void OnDestroy()
        {
            if (null != m_HorizonalHistogramBuffer)
            {
                m_HorizonalHistogramBuffer.Release();
                m_HorizonalHistogramBuffer = null;
            }

            if (null != m_VerticalHistogramBuffer)
            {
                m_VerticalHistogramBuffer.Release();
                m_VerticalHistogramBuffer = null;
            }
        }

    }
}