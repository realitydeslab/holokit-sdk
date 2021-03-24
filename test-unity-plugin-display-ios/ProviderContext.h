#pragma once

#include <cassert>

struct IUnityXRTrace;
struct IUnityXRDisplayInterface;
struct IUnityXRInputInterface;

class ExampleDisplayProvider;
class ExampleTrackingProvider;

struct ProviderContext
{
    IUnityInterfaces* interfaces;
    IUnityXRTrace* trace;

    IUnityXRDisplayInterface* display;
    ExampleDisplayProvider* displayProvider;

    IUnityXRInputInterface* input;
    ExampleTrackingProvider* trackingProvider;
};

inline ProviderContext& GetProviderContext(void* data)
{
    assert(data != NULL);
    return *static_cast<ProviderContext*>(data);
}

class ProviderImpl
{
public:
    ProviderImpl(ProviderContext& ctx, UnitySubsystemHandle handle)
        : m_Ctx(ctx)
        , m_Handle(handle)
    {
    }
    virtual ~ProviderImpl() {}

    virtual UnitySubsystemErrorCode Initialize() = 0;
    virtual UnitySubsystemErrorCode Start() = 0;

    virtual void Stop() = 0;
    virtual void Shutdown() = 0;

protected:
    ProviderContext& m_Ctx;
    UnitySubsystemHandle m_Handle;
};
