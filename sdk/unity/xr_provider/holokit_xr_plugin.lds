VERS_1.0 {
  global:
    # Exports from holokit_xr_plugin
    UnityPluginLoad*;
    *LoadDisplay*;
    *LoadInput*;
    *HoloKitRotationToUnityPose*;
    *HoloKitTransformToUnityPose*;

    # Exports from unity_jni_android
    JNI_OnLoad;
    getJavaVm;
    HoloKitUnity_initializeAndroid;

    # Exports from holokit_xr_unity
    HoloKitUnity_setScreenParams;
    HoloKitUnity_setWidgetCount;
    HoloKitUnity_setWidgetParams;
    HoloKitUnity_setDeviceParametersChanged;

    # Exports from holokit api
    HoloKit*;

  local:
   *;
};