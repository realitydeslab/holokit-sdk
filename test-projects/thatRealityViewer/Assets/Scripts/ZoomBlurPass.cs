using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;

//首先我们创建ZoomBlurPass类让它继承自 ScriptableRenderPass，


public class ZoomBlurPass : ScriptableRenderPass
{
    //接着我们需要创建一个k_RenderTag 值为"Render ZoomBlur Effects"的标记，
    //因为我们后续需要在CommandBufferPool中去获取到它，这样的话我们在FrameDebugger中也可以找到它。
    static readonly string k_RenderTag = "Render ZoomBlur Effects";

    //紧接着我们需要创建对应的变量 给这些参数创建缓冲区，
    //这些是预先计算好的属性id，后面给Shader赋值的时候用ID会比用字符串快。
    static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    static readonly int TempTargetId = Shader.PropertyToID("TempTargetZoomBlur");
    static readonly int FocusPowerId = Shader.PropertyToID("_FocusPower");
    static readonly int FocusDetailId = Shader.PropertyToID("_FocusDetail");
    static readonly int FocusScreenPositionId = Shader.PropertyToID("_FocusScreenPosition");
    static readonly int ReferenceResolutionXId = Shader.PropertyToID("_ReferenceResolutionX");

    //然后我们创建成员变量ZoomBlur zoomBlur、Material zoomBlurMaterial、RenderTargetIdentifier currentTarget;
    ZoomBlur zoomBlur;
    Material zoomBlurMaterial;
    RenderTargetIdentifier currentTarget;
    RenderPassEvent renderPassEvent;

    //接着就是完成ZoomBlurPass的构造函数，
    //这里的renderPassEvent必须正确赋值才能保证该ZoomBlurPass类在正确的RenderPassEvent的顺序下渲染
    //(这里renderPassEvent的值为BeforeRenderingPostProcessing);
    public ZoomBlurPass(RenderPassEvent evt)
    {
        renderPassEvent = evt;

        var shader = Shader.Find("PostEffect/ZoomBlur");
        if(shader == null)
        {
            Debug.LogError("Shader not found.");
            return;
        }

        zoomBlurMaterial = CoreUtils.CreateEngineMaterial(shader);
    }

    //接着我们来写一个接口，将currentTarget传进去；
    public void Setup(in RenderTargetIdentifier currentTarget)
    {
        this.currentTarget = currentTarget;
    }

    //接下来，Execute方法里执行CommandBuffer的方法
    //然后就来实现ZoomBlurPass这个类的核心方法Execute（）来定义我们的执行规则,
    //也就是在Override的Execute方法里做我们的具体的后处理。
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        //我们来简单的看下：首先是环境的准备，是否创建材质
        if(zoomBlurMaterial == null)
        {
            Debug.LogError("blur material not found");

            var shader = Shader.Find("PostEffect/ZoomBlur");
            if (shader == null)
            {
                Debug.LogError("Shader not found.");
                return;
            }

            zoomBlurMaterial = CoreUtils.CreateEngineMaterial(shader);

            return;
        }

        //后效是否生效
        if (!renderingData.cameraData.postProcessEnabled) return;

        //使用VolumeManager.instance.stack的GetComponent方法来获得我们的自定义Volume类的实例;并获取里面的属性变量来做具体的后处理
        var stack = VolumeManager.instance.stack;
        zoomBlur = stack.GetComponent<ZoomBlur>();

        if (zoomBlur == null) { return; }
        if (!zoomBlur.IsActive()) { return; }

        //然后从命令缓存池中获取一个gl命令缓存，CommandBuffer主要用于收集一系列gl指令，然后之后执行
        var cmd = CommandBufferPool.Get(k_RenderTag);

        //我们要在Render中实现渲染逻辑，这里用到了两次Blit，
        //另外我们使用camera buffer的 CommandBuffer.GetTemporaryRT方法来申请这样一张texture。
        //传入着色器属性ID以及与相机像素尺寸相匹配的纹理宽高。
        Render(cmd, ref renderingData);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref var cameraData = ref renderingData.cameraData;
        var source = currentTarget;
        int destination = TempTargetId;

        var w = cameraData.camera.scaledPixelWidth;
        var h = cameraData.camera.scaledPixelHeight;

        // 设置
        zoomBlurMaterial.SetFloat(FocusPowerId, zoomBlur.focusPower.value);
        zoomBlurMaterial.SetInt(FocusDetailId, zoomBlur.focusDetail.value);
        zoomBlurMaterial.SetVector(FocusScreenPositionId, zoomBlur.foucusScreenPosition.value);
        zoomBlurMaterial.SetInt(ReferenceResolutionXId, zoomBlur.referenceResolutionX.value);
        //shader 的第一个pass
        int shaderPass = 0;

        cmd.SetGlobalTexture(MainTexId,source);
        //在清理Render target之前，如果存在后处理栈就需要申请一张临时的render tex。
        // 我们使用camera buffer的Command。Buffer。GetTemporaryRT方法来申请这样一张render tex。
        // 传入着色器属性ID以及相机像素尺寸相匹配的纹理宽高，FilterMode， RenderTextureFormat/
        cmd.GetTemporaryRT(destination, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);

        if (Display.displays.Length > 1)
        {
            //List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            //SubsystemManager.GetSubsystems(displaySubsystems);
            //XRDisplaySubsystem displaySubsystem = displaySubsystems[0];
            Display secondDisplay = Display.displays[1];
            
            RenderTargetIdentifier destId = new RenderTargetIdentifier(secondDisplay.colorBuffer);
            
            

            cmd.Blit(source, destination, zoomBlurMaterial, shaderPass);
            cmd.SetRenderTarget(secondDisplay.colorBuffer, secondDisplay.depthBuffer);
            cmd.Blit(destination, secondDisplay.colorBuffer);

            //cmd.Blit(destination, source);
            return;
        }
        else
        {
            List<XRDisplaySubsystem> displaySubsystems = new List<XRDisplaySubsystem>();
            SubsystemManager.GetSubsystems(displaySubsystems);
            XRDisplaySubsystem displaySubsystem;


            if (displaySubsystems.Count > 0)
            {
                displaySubsystem = displaySubsystems[0];
                if (displaySubsystem.GetRenderPassCount() > 2)
                {
                    Debug.Log("fuck");
                    displaySubsystem.GetRenderPass(2, out var renderPass);
                  
                    cmd.Blit(RenderTexture.GetTemporary(renderPass.renderTargetDesc), destination, zoomBlurMaterial, shaderPass);
                    cmd.Blit(destination, source);
                    return;
                }
                else
                {
                    displaySubsystem.GetRenderPass(0, out var renderPass);
                    cmd.Blit(RenderTexture.GetTemporary(renderPass.renderTargetDesc), destination, zoomBlurMaterial, shaderPass);
                    cmd.Blit(destination, source);
                }
            }


            
            cmd.Blit(source, destination, zoomBlurMaterial, shaderPass);
            cmd.Blit(destination, source);
        }
        
    }
}
