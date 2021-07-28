using System.Collections.Generic;
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
        public XRDisplaySubsystem DisplaySubsystem;

        RenderTargetIdentifier m_CameraColorTargetId;

        RenderTexture m_SecondCameraRenderTexture;

        //RenderTargetHandle tempTexture;

        public void Setup(RenderTargetIdentifier cameraColorTargetId, RenderTexture secondCameraRenderTexture)
        {
            this.m_CameraColorTargetId = cameraColorTargetId;
            this.m_SecondCameraRenderTexture = secondCameraRenderTexture;
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
                if (DisplaySubsystem.GetRenderPassCount() > 2)
                {
                    //Display secondDisplay = Display.displays[1];
                    DisplaySubsystem.GetRenderPass(2, out var renderPass);
                    CommandBuffer cmd = CommandBufferPool.Get("Second Display Blit");
                    cmd.Clear();

                    //cmd.Blit(renderPass.renderTarget, m_CameraColorTargetId);

                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
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
            m_ScriptablePass.DisplaySubsystem = displaySubsystems[0];
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


