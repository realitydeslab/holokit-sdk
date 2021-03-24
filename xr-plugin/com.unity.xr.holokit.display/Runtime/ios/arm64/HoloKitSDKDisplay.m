#import <Foundation/Foundation.h>
#include "IUnityInterface.h"

#ifdef __cplusplus
extern "C" {
#endif

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginLoad(IUnityInterfaces* unityInterfaces);

#ifdef __cplusplus
} // extern "C"
#endif

@interface HoloKitSDKDisplay : NSObject

+ (void)loadPlugin;

@end

@implementation HoloKitSDKDisplay

+ (void)loadPlugin
{
    // This registers our plugin with Unity
    UnityRegisterRenderingPluginV5(UnityPluginLoad, NULL);
}

@end
