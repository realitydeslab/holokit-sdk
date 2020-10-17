#import <Foundation/Foundation.h>
#include "IUnityInterface.h"
#include "UnityAppController.h"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityHoloKitXRPlugin_PluginLoad(IUnityInterfaces* unityInterfaces);

@interface UnityHoloKit : NSObject

+ (void)loadPlugin;

@end

@implementation UnityHoloKit

+ (void)loadPlugin
{
    // This registers our plugin with Unity
    UnityRegisterRenderingPluginV5(UnityHoloKitXRPlugin_PluginLoad, NULL);
}

@end
