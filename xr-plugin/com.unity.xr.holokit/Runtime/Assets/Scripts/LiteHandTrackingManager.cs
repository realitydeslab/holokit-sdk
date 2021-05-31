using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;

namespace UnityEngine.XR.HoloKit
{
    public class LiteHandTrackingManager : MonoBehaviour
    {

        [SerializeField] private AROcclusionManager m_OcclusionManager;

        //public GameObject m_Quad;

        public ComputeShader m_ComputeShader;

        private ComputeBuffer m_ComputeBuffer;

        private Vector3[] m_ResultBuffer;

        private RenderTexture m_QuadRenderTexture;

        private int m_Width = 256;

        private int m_Height = 192;

        private int m_Kernel;

        private bool m_IsHandValid = false;

        private const float k_MaxHandDepth = 0.6f;

        private const int k_MinHandPixelsThreshold = 500;

        private Camera m_ArCamera;

        [SerializeField] GameObject m_HandSphere;

        // Start is called before the first frame update
        void Start()
        {
            //m_OcclusionManager = GetComponent<AROcclusionManager>();

            m_ArCamera = Camera.main;

            m_ComputeBuffer = new ComputeBuffer(m_Width * m_Height, sizeof(float) * 3);

            m_Kernel = m_ComputeShader.FindKernel("CSMain");
            m_QuadRenderTexture = new RenderTexture(m_Width, m_Height, 1);
            m_QuadRenderTexture.enableRandomWrite = true;
            m_QuadRenderTexture.Create();

            //m_Quad.GetComponent<MeshRenderer>().material.SetTexture("_MainTex", m_QuadRenderTexture);
            //m_ComputeShader.SetTexture(m_Kernel, "Result", m_QuadRenderTexture);
            m_ComputeShader.SetBuffer(m_Kernel, "ResultBuffer", m_ComputeBuffer);
            m_ComputeShader.SetFloat("Width", m_Width);
            m_ComputeShader.SetFloat("Height", m_Height);
            m_ComputeShader.SetFloat("MaxDepth", k_MaxHandDepth);

            m_ResultBuffer = new Vector3[m_Width * m_Height];
            for (int i = 0; i < m_Width * m_Height; i++)
            {
                m_ResultBuffer[i] = new Vector3(0, 0, 0);
            }
        }

        // Update is called once per frame
        void Update()
        {
            if (m_OcclusionManager.humanDepthTexture != null)
            {
                m_ComputeShader.SetTexture(m_Kernel, "DepthTexture", m_OcclusionManager.humanDepthTexture);
                m_ComputeShader.SetTexture(m_Kernel, "StencilTexture", m_OcclusionManager.humanStencilTexture);
                m_ComputeShader.Dispatch(m_Kernel, Mathf.CeilToInt(m_Width / 8f), Mathf.CeilToInt(m_Height / 8f), 1);
                m_ComputeBuffer.GetData(m_ResultBuffer);

                Vector3 screenSpacePoint = WeightedAverage(m_ResultBuffer);
                if (m_IsHandValid)
                {
                    m_HandSphere.SetActive(true);
                    float xCoordinate = (screenSpacePoint.x / (m_Width - 1)) * (Screen.width - 1) + 1;
                    float yCoordinate = (screenSpacePoint.y / (m_Height - 1)) * (Screen.height - 1) + 1;
                    m_HandSphere.transform.position = m_ArCamera.ScreenToWorldPoint(new Vector3(xCoordinate, yCoordinate, screenSpacePoint.z));
                }
                else
                {
                    m_HandSphere.SetActive(false);
                }
            }
        }

        Vector3 WeightedAverage(Vector3[] input)
        {
            Vector3 accumulatedResult = new Vector3(0, 0, 0);
            int pixelSum = 0;
            float totalWeight = 0;
            int length = input.Length;
            for (int i = 0; i < length; i++)
            {
                if (input[i].x != 0 || input[i].y != 0)
                {
                    float weight = Mathf.FloorToInt(i / (float)m_Width) + 1;
                    accumulatedResult += input[i] * weight * weight;
                    totalWeight += weight * weight;
                    pixelSum++;
                }
            }
            if (pixelSum > k_MinHandPixelsThreshold)
            {
                m_IsHandValid = true;
            }
            else
            {
                m_IsHandValid = false;
                m_HandSphere.transform.position = new Vector3(0f, 3f, 0f);
            }
            return new Vector3(accumulatedResult.x / totalWeight, accumulatedResult.y / totalWeight, accumulatedResult.z / totalWeight);
        }
    }
}