#include "IUnityInterface.h"
#include "XR/IUnityXRTrace.h"
#include "XR/UnitySubsystemTypes.h"

#include "ProviderContext.h"

static ProviderContext* s_Context{};

UnitySubsystemErrorCode Load_Display(ProviderContext&);
UnitySubsystemErrorCode Load_Input(ProviderContext&);

static bool ReportError(const char* name, UnitySubsystemErrorCode err)
{
    if (err != kUnitySubsystemErrorCodeSuccess)
    {
        XR_TRACE_ERROR(s_Context->trace, "Error loading subsystem: %s (%d)\n", name, err);
        return true;
    }
    return false;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginLoad(IUnityInterfaces* unityInterfaces)
{
    
    auto* ctx = s_Context = new ProviderContext;

    ctx->interfaces = unityInterfaces;
    ctx->trace = unityInterfaces->Get<IUnityXRTrace>();

    XR_TRACE_LOG(ctx->trace, "<<<<<<<<<< display UnityPluginLoad()\n");
    
    if (ReportError("Display", Load_Display(*ctx)))
        return;

    if (ReportError("Input", Load_Input(*ctx)))
        return;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityPluginUnload()
{
    delete s_Context;
}
