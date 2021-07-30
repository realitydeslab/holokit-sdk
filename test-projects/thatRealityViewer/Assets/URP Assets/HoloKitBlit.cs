using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;
using UnityEngine.XR.HoloKit;

public class HoloKitBlit : ScriptableRendererFeature
{
    [System.Serializable]
    public class FeatureSettings
    {
        public RenderTexture SecondCameraRenderTexture;
    }

    public FeatureSettings settings = new FeatureSettings();

    class CustomRenderPass : ScriptableRenderPass
    {
        const string k_CustomRenderPassName = "HoloKit Mirror Blit";
        public XRDisplaySubsystem m_DisplaySubsystem;

        RenderTargetIdentifier m_CameraColorTargetId;

        RenderTexture m_SecondCameraRenderTexture;

        Display m_SecondDisplay;

        private Material copyMaterial;

        //RenderTargetHandle tempTexture;

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSecondDisplayAvailable(bool value);

        [DllImport("__Internal")]
        private static extern void UnityHoloKit_SetSecondDisplayNativeRenderBufferPtr(IntPtr nativeRenderBufferPtr);

        public void Setup(RenderTargetIdentifier cameraColorTargetId, RenderTexture secondCameraRenderTexture)
        {
            this.m_CameraColorTargetId = cameraColorTargetId;
            this.m_SecondCameraRenderTexture = secondCameraRenderTexture;

            Shader shader = Shader.Find("Hidden/BlitCopy");
            copyMaterial = new Material(shader);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            //cmd.GetTemporaryRT(tempTexture.id, cameraTextureDescriptor);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (Display.displays.Length > 1)
            {
                {
                    m_SecondDisplay = Display.displays[1];
                    //m_SecondDisplay.SetRenderingResolution(Display.main.renderingWidth, Display.main.renderingHeight);
                    Debug.Log($"Main display width {Display.main.renderingWidth} and height {Display.main.renderingHeight}");

                    m_SecondDisplay.SetRenderingResolution(Display.main.renderingWidth, Display.main.renderingHeight);
                    //UnityHoloKit_SetSecondDisplayNativeRenderBufferPtr(m_SecondDisplay.colorBuffer.GetNativeRenderBufferPtr());
                    //UnityHoloKit_SetSecondDisplayAvailable(true);

                    var cmd = CommandBufferPool.Get(k_CustomRenderPassName);
                    cmd.BeginSample(k_CustomRenderPassName);

                    //   cmd.SetRenderTarget(, m_SecondDisplay.depthBuffer);
                    //RenderTargetIdentifier ss = new RenderTargetIdentifier(m_SecondDisplay.colorBuffer);

                    m_DisplaySubsystem.GetRenderPass(0, out var renderPass);


                    var shader = Shader.Find("PostEffect/ZoomBlur");
                    if (shader == null)
                    {
                        Debug.LogError("Shader not found.");
                        return;
                    }

                    Material zoomBlurMaterial = CoreUtils.CreateEngineMaterial(shader);
                    cmd.Blit(m_CameraColorTargetId, m_CameraColorTargetId, copyMaterial);

                    cmd.EndSample(k_CustomRenderPassName);
                    context.ExecuteCommandBuffer(cmd);

                    CommandBufferPool.Release(cmd);
                }
            }
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRendering;

        List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
        SubsystemManager.GetSubsystems(displaySubsystems);
        if (displaySubsystems.Count > 0)
        {
            m_ScriptablePass.m_DisplaySubsystem = displaySubsystems[0];
        }
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraColorTargetId = renderer.cameraColorTarget;


        m_ScriptablePass.Setup(cameraColorTargetId, settings.SecondCameraRenderTexture);

        renderer.EnqueuePass(m_ScriptablePass);
    }
}


