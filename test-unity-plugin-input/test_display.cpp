//
//  test_display.cpp
//  test-unity-plugin-input
//
//  Created by Yuchen on 2021/3/8.
//

#include <array>
#include <cassert>
#include <map>
#include <memory>
#include <vector>

#include "IUnityInterface.h"
#include "IUnityXRDisplay.h"
#include "IUnityXRTrace.h"
#include "UnitySubsystemTypes.h"
#include "ProviderContext.h"

// @def Logs to Unity XR Trace interface @p message.
#define HOLOKIT_DISPLAY_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrDisplayProvider]: " message "\n", \
               ##__VA_ARGS__)

#define SIDE_BY_SIDE 0
#define NUM_RENDER_PASSES 2
static const float s_PoseXPositionPerPass[] = {-1.0f, 1.0f};

// BEGIN WORKAROUND: skip first frame since we get invalid data.  Fix coming to trunk.
static bool s_SkipFrame = true;
#define WORKAROUND_SKIP_FIRST_FRAME()           \
    if (s_SkipFrame)                            \
    {                                           \
        s_SkipFrame = false;                    \
        return kUnitySubsystemErrorCodeSuccess; \
    }
#define WORKAROUND_RESET_SKIP_FIRST_FRAME() s_SkipFrame = true;
// END WORKAROUND


// @brief Holds the implementation methods of UnityLifecycleProvider and
//        UnityXRDisplayGraphicsThreadProvider
class HoloKitDisplayProvider : ProviderImpl {
public:
    HoloKitDisplayProvider(ProviderContext& ctx, UnitySubsystemHandle handle)
    : ProviderImpl(ctx, handle)
    {
    }
    
    UnitySubsystemErrorCode Initialize() override;
    UnitySubsystemErrorCode Start() override;
    
    UnitySubsystemErrorCode GfxThread_Start(UnityXRRenderingCapabilities& renderingCaps);
    
    UnitySubsystemErrorCode GfxThread_SubmitCurrentFrame();
    UnitySubsystemErrorCode GfxThread_PupulateNextFrameDesc(const UnityXRFrameSetupHints& frameHints, UnityXRNextFrameDesc& nextFrame);
    
    UnitySubsystemErrorCode GfxThread_Stop();
    UnitySubsystemErrorCode GfxThread_FinalBlitToGameViewBackBuffer(const UnityXRMirrorViewBlitInfo* mirrorBlitInfo, ProviderContext& ctx);
    
    UnitySubsystemErrorCode QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo* mirrorBlitInfo, UnityXRMirrorViewBlitDesc* blitDescriptor, ProviderContext& ctx);
    
    void Stop() override;
    void Shutdown() override;
    
private:
    void CreateTextures(int numTextures, int textureArrayLength, float requestedTextureScale);
    void DestroyTextures();
    
    UnityXRPose GetPose(int pass);
    UnityXRProjection GetProjection(int pass);
    
    std::vector<void*> m_NativeTextures;
    std::vector<UnityXRRenderTextureId> m_UnityTextures;
};

UnitySubsystemErrorCode HoloKitDisplayProvider::Initialize() {
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::Start() {
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::GfxThread_Start(UnityXRRenderingCapabilities &renderingCaps) {
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::GfxThread_SubmitCurrentFrame() {
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::GfxThread_PupulateNextFrameDesc(const UnityXRFrameSetupHints& frameHints, UnityXRNextFrameDesc& nextFrame) {
    WORKAROUND_SKIP_FIRST_FRAME();
    
    bool reallocateTextures = (m_UnityTextures.size() == 0);
    if ((kUnityXRFrameSetupHintsChangedSinglePassRendering & frameHints.changedFlags) != 0)
    {
        reallocateTextures = true;
    }
    if ((kUnityXRFrameSetupHintsChangedRenderViewport & frameHints.changedFlags) != 0)
    {
        // Change sampling UVs for compositor, pass through new viewport on `nextFrame`
    }
    if ((kUnityXRFrameSetupHintsChangedTextureResolutionScale & frameHints.changedFlags) != 0)
    {
        reallocateTextures = true;
    }
    if ((kUnityXRFrameSetuphintsChangedContentProtectionState & frameHints.changedFlags) != 0)
    {
        // App wants different content protection mode.
    }
    if ((kUnityXRFrameSetuphintsChangedReprojectionMode & frameHints.changedFlags) != 0)
    {
        // App wants different reprojection mode, configure compositor if possible.
    }
    if ((kUnityXRFrameSetuphintsChangedFocusPlane & frameHints.changedFlags) != 0)
    {
        // App changed focus plane, configure compositor if possible.
    }
    
    if(reallocateTextures) {
        DestroyTextures();
        
        int numTextures = frameHints.appSetup.singlePassRendering ? NUM_RENDER_PASSES - 1 : NUM_RENDER_PASSES;
        int textureArrayLength = frameHints.appSetup.singlePassRendering ? 2 : 0;
        
        CreateTextures(numTextures, textureArrayLength, frameHints.appSetup.textureResolutionScale);
    }
    
    if(!frameHints.appSetup.singlePassRendering) {
        // Use multi-pass rendering to render
        nextFrame.renderPassesCount = NUM_RENDER_PASSES;
        
        for(int pass = 0; pass < nextFrame.renderPassesCount; ++pass) {
            auto& renderPass = nextFrame.renderPasses[pass];
            
            renderPass.textureId = m_UnityTextures[pass];
            
            renderPass.renderParamsCount = 1;
            renderPass.cullingPassIndex = pass;
            auto& cullingPass = nextFrame.cullingPasses[pass];
            cullingPass.separation = fabs(s_PoseXPositionPerPass[1]) + fabs(s_PoseXPositionPerPass[0]);
            
            auto& renderParams = renderPass.renderParams[0];
            renderParams.deviceAnchorToEyePose = cullingPass.deviceAnchorToCullingPose = GetPose(pass);
            renderParams.projection = cullingPass.projection = GetProjection(pass);
            
            
            renderParams.viewportRect = frameHints.appSetup.renderViewport;
        }
    } else {
        // Example of using single-pass stereo to combine the first two render passes.
        // TODO: fill it
    }
    
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::GfxThread_Stop() {
    WORKAROUND_RESET_SKIP_FIRST_FRAME();
    return kUnitySubsystemErrorCodeSuccess;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::GfxThread_FinalBlitToGameViewBackBuffer(const UnityXRMirrorViewBlitInfo *mirrorBlitInfo, ProviderContext &ctx) {
    // TODO: metal here
    
    return kUnitySubsystemErrorCodeSuccess;
}

void HoloKitDisplayProvider::Stop() {
    
}

void HoloKitDisplayProvider::Shutdown() {
    
}

void HoloKitDisplayProvider::CreateTextures(int numTextures, int textureArrayLength, float requestedTextureScale) {
    const int texWidth = (int)(1920.0f * requestedTextureScale * (SIDE_BY_SIDE ? 2.0f : 1.0f));
    const int texHeight = (int)(1200.0f * requestedTextureScale);
    
    m_NativeTextures.resize(numTextures);
    m_UnityTextures.resize(numTextures);
    
    for (int i = 0; i < numTextures; i++) {
        UnityXRRenderTextureDesc uDesc{};
        
        uDesc.color.nativePtr = (void*)kUnityXRRenderTextureIdDontCare;
        uDesc.width = texWidth;
        uDesc.height = texHeight;
        uDesc.textureArrayLength = textureArrayLength;
        
        // Create a UnityXRRenderTextureId for the native texture so we can tell unity to render to it later.
        UnityXRRenderTextureId uTexId;
        m_Ctx.display->CreateTexture(m_Handle, &uDesc, &uTexId);
        m_UnityTextures[i] = uTexId;
    }
}

void HoloKitDisplayProvider::DestroyTextures() {
    for (int i = 0; i < m_UnityTextures.size(); ++i) {
        if(m_UnityTextures[i] != 0) {
            m_Ctx.display->DestroyTexture(m_Handle, m_UnityTextures[i]);
        }
    }
    
    m_UnityTextures.clear();
    m_NativeTextures.clear();
}

UnityXRPose HoloKitDisplayProvider::GetPose(int pass) {
    UnityXRPose pose{};
    if (pass < (sizeof(s_PoseXPositionPerPass) / sizeof(s_PoseXPositionPerPass[0]))) {
        pose.position.x = s_PoseXPositionPerPass[pass];
    }
    pose.position.z = -10.0f;
    pose.rotation.w = 1.0f;
    return pose;
}

UnityXRProjection HoloKitDisplayProvider::GetProjection(int pass) {
    UnityXRProjection ret;
    ret.type = kUnityXRProjectionTypeHalfAngles;
    ret.data.halfAngles.left = -1.0;
    ret.data.halfAngles.right = 1.0;
    ret.data.halfAngles.top = 0.625;
    ret.data.halfAngles.bottom = -0.625;
    return ret;
}

UnitySubsystemErrorCode HoloKitDisplayProvider::QueryMirrorViewBlitDesc(const UnityXRMirrorViewBlitInfo *mirrorBlitInfo, UnityXRMirrorViewBlitDesc *blitDescriptor, ProviderContext &ctx) {
    if (ctx.displayProvider->m_UnityTextures.size() == 0) {
        // Eye texture is not available yet, return failure
        return kUnitySubsystemErrorCodeFailure;
    }
    int srcTexId = ctx.displayProvider->m_UnityTextures[0];
    const UnityXRVector2 sourceTextureSize = { static_cast<float>(1920), static_cast<float>(1200) };
    const UnityXRRectf sourceUVRect = { 0.0f, 0.0f, 1.0f, 1.0f };
    const UnityXRVector2 destTextureSize = { static_cast<float>(mirrorBlitInfo->mirrorRtDesc->rtScaledWidth), static_cast<float>(mirrorBlitInfo->mirrorRtDesc->rtScaledHeight)};
    const UnityXRRectf destUVRect = { 0.0f, 0.0f, 1.0f, 1.0f };
    
    UnityXRVector2 sourceUV0, sourceUV1, destUV0, destUV1;
    
    float sourceAspect = (sourceTextureSize.x * sourceUVRect.width) / (sourceTextureSize.y * sourceUVRect.height);
    float destAspect = (destTextureSize.x * destUVRect.width) / (destTextureSize.y * destUVRect.height);
    float ratio = sourceAspect / destAspect;
    UnityXRVector2 sourceUVCenter = { sourceUVRect.x + sourceUVRect.width * 0.5f, sourceUVRect.y + sourceUVRect.height * 0.5f };
    UnityXRVector2 sourceUVSize = { sourceUVRect.width, sourceUVRect.height };
    UnityXRVector2 destUVCenter = { destUVRect.x + destUVRect.width * 0.5f, destUVRect.y + destUVRect.height * 0.5f };
    UnityXRVector2 destUVSize = { destUVRect.width, destUVRect.height };
    
    if (ratio > 1.0f) {
        sourceUVSize.x /= ratio;
    } else {
        sourceUVSize.y *= ratio;
    }
    
    sourceUV0 = {sourceUVCenter.x - (sourceUVSize.x * 0.5f), sourceUVCenter.y - (sourceUVSize.y * 0.5f)};
    sourceUV1 = {sourceUV0.x + sourceUVSize.x, sourceUV0.y + sourceUVSize.y};
    destUV0 = {destUVCenter.x - destUVSize.x * 0.5f, destUVCenter.y - destUVSize.y * 0.5f};
    destUV1 = {destUV0.x + destUVSize.x, destUV0.y + destUVSize.y};
    
    (*blitDescriptor).blitParamsCount = 1;
    (*blitDescriptor).blitParams[0].srcTexId = srcTexId;
    (*blitDescriptor).blitParams[0].srcTexArraySlice = 0;
    (*blitDescriptor).blitParams[0].srcRect = {sourceUV0.x, sourceUV0.y, sourceUV1.x - sourceUV0.x, sourceUV1.y - sourceUV0.y};
    (*blitDescriptor).blitParams[0].destRect = {destUV0.x, destUV0.y, destUV1.x - destUV0.x, destUV1.y - destUV0.y};
    
    return kUnitySubsystemErrorCodeSuccess;
}

static UnitySubsystemErrorCode UNITY_INTERFACE_API Display_Initialize(UnitySubsystemHandle handle, void* userData) {
    auto& ctx = GetProviderContext(userData);
    
    ctx.displayProvider = new HoloKitDisplayProvider(ctx, handle);
    
    // Register for callbacks on the graphics thread.
    UnityXRDisplayGraphicsThreadProvider gfxThreadProvider{};
    gfxThreadProvider.userData = &ctx;
    
    gfxThreadProvider.Start = [](UnitySubsystemHandle handle, void* userData, UnityXRRenderingCapabilities* renderingCaps) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_Start(*renderingCaps);
    };
    
    gfxThreadProvider.SubmitCurrentFrame = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_SubmitCurrentFrame();
    };
    
    gfxThreadProvider.PopulateNextFrameDesc = [](UnitySubsystemHandle handle, void* userData, const UnityXRFrameSetupHints* frameHints, UnityXRNextFrameDesc* nextFrame) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_PupulateNextFrameDesc(*frameHints, *nextFrame);
    };
    
    gfxThreadProvider.Stop = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_Stop();
    };
    
    gfxThreadProvider.BlitToMirrorViewRenderTarget = [](UnitySubsystemHandle handle, void* userData, const UnityXRMirrorViewBlitInfo mirrorBlitInfo) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->GfxThread_FinalBlitToGameViewBackBuffer(&mirrorBlitInfo, ctx);
    };
    
    ctx.display->RegisterProviderForGraphicsThread(handle, &gfxThreadProvider);
    
    UnityXRDisplayProvider provider{&ctx, NULL, NULL};
    provider.QueryMirrorViewBlitDesc = [](UnitySubsystemHandle handle, void* userData, const UnityXRMirrorViewBlitInfo mirrorBlitInfo, UnityXRMirrorViewBlitDesc* blitDescriptor) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->QueryMirrorViewBlitDesc(&mirrorBlitInfo, blitDescriptor, ctx);
    };
    
    ctx.display->RegisterProvider(handle, &provider);
    
    return ctx.displayProvider->Initialize();
}
    

UnitySubsystemErrorCode Load_Display(ProviderContext& ctx) {
    ctx.display = ctx.interfaces->Get<IUnityXRDisplayInterface>();
    if(ctx.display == NULL) {
        return kUnitySubsystemErrorCodeFailure;
    }
    
    UnityLifecycleProvider displayLifecycleHandler{};
    displayLifecycleHandler.userData = &ctx;
    displayLifecycleHandler.Initialize = &Display_Initialize;
    
    displayLifecycleHandler.Start = [](UnitySubsystemHandle handle, void* userData) -> UnitySubsystemErrorCode {
        auto& ctx = GetProviderContext(userData);
        return ctx.displayProvider->Start();
    };
    
    displayLifecycleHandler.Stop = [](UnitySubsystemHandle handle, void* userData) -> void {
        auto& ctx = GetProviderContext(userData);
        ctx.displayProvider->Stop();
    };
    
    displayLifecycleHandler.Shutdown = [](UnitySubsystemHandle handle, void* userData) -> void {
        auto& ctx = GetProviderContext(userData);
        ctx.displayProvider->Shutdown();
        delete ctx.displayProvider;
    };
    
    // id of the subsystem is "HoloKit Display"
    return ctx.display->RegisterLifecycleProvider("HoloKit SDK Display Subsystem", "HoloKit Display", &displayLifecycleHandler);
}

extern "C" {

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unityInterfaces) {
    auto* ctx = new ProviderContext;
    
    ctx->interfaces = unityInterfaces;
    ctx->trace = unityInterfaces->Get<IUnityXRTrace>();
    
    Load_Display(*ctx);
}

}
