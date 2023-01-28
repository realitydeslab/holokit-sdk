#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <UIKit/UIKit.h>
#import "DeviceProfile.h"

typedef struct {
    simd_float4 LeftViewportRect;
    simd_float4 RightViewportRect;
    float NearClipPlane;
    float FarClipPlane;
    simd_float4x4 LeftProjectionMatrix;
    simd_float4x4 RightProjectionMatrix;
    simd_float3 CameraToCenterEyeOffset;
    simd_float3 CameraToScreenCenterOffset;
    simd_float3 CenterEyeToLeftEyeOffset;
    simd_float3 CenterEyeToRightEyeOffset;
} HoloKitCameraData;

@interface StarManager : NSObject

@end

@interface StarManager()

@end

@implementation StarManager

+ (HoloKitCameraData)getHoloKitCameraData:(HoloKitModel)holokitModel ipd:(float)ipd farClipPlane:(float)farClipPlane {
    PhoneModel phoneModel = [DeviceProfile getPhoneModel];
    
    float viewportWidthInMeters = holokitModel.ViewportInner + holokitModel.ViewportOuter;
    float viewportHeightInMeters = holokitModel.ViewportTop + holokitModel.ViewportBottom;
    float nearClipPlane = holokitModel.LensToEye;
    float viewportsFullWidthInMeters = holokitModel.OpticalAxisDistance + 2.0 * holokitModel.ViewportOuter;
    float gap = viewportsFullWidthInMeters - viewportWidthInMeters * 2.0;
    
    simd_float4x4 leftProjectionMatrix = matrix_identity_float4x4;
    leftProjectionMatrix.columns[0].x = 2.0 * nearClipPlane / viewportWidthInMeters;
    leftProjectionMatrix.columns[1].y = 2.0 * nearClipPlane / viewportHeightInMeters;
    leftProjectionMatrix.columns[2].x = (ipd - viewportWidthInMeters - gap) / viewportWidthInMeters;
    leftProjectionMatrix.columns[2].z = (-farClipPlane - nearClipPlane) / (farClipPlane - nearClipPlane);
    leftProjectionMatrix.columns[3].z = -2.0 * farClipPlane * nearClipPlane / (farClipPlane - nearClipPlane);
    leftProjectionMatrix.columns[2].w = -1.0;
    leftProjectionMatrix.columns[3].w = 0.0;
    
    simd_float4x4 rightProjectionMatrix = leftProjectionMatrix;
    rightProjectionMatrix.columns[2].x = -leftProjectionMatrix.columns[2].x;
    
    // 2. Calculate viewport rects
    float centerX = 0.5;
    float centerY = (holokitModel.AxisToBottom - phoneModel.ScreenBottom) / phoneModel.ScreenHeight;
    float fullWidth = viewportsFullWidthInMeters / phoneModel.ScreenWidth;
    float width = viewportWidthInMeters / phoneModel.ScreenWidth;
    float height = viewportHeightInMeters / phoneModel.ScreenHeight;
    
    float xMinLeft = centerX - fullWidth / 2.0;
    float xMaxLeft = xMinLeft + width;
    float xMinRight = centerX + fullWidth / 2.0 - width;
    float xMaxRight = xMinRight + width;
    float yMin = centerY - height / 2.0;
    float yMax = centerY + height / 2.0;
    
    simd_float4 leftViewportRect = simd_make_float4(xMinLeft, yMin, xMaxLeft, yMax);
    simd_float4 rightViewportRect = simd_make_float4(xMinRight, yMin, xMaxRight, yMax);
    
    // 3. Calculate offsets
    simd_float3 cameraToCenterEyeOffset = phoneModel.CameraOffset + holokitModel.MrOffset;
    simd_float3 cameraToScreenCenterOffset = phoneModel.CameraOffset + simd_make_float3(0.0, phoneModel.ScreenBottom + (phoneModel.ScreenHeight / 2.0), 0.0);
    simd_float3 centerEyeToLeftEyeOffset = simd_make_float3(-ipd / 2.0, 0.0, 0.0);
    simd_float3 centerEyeToRightEyeOffset = simd_make_float3(ipd / 2.0, 0.0, 0.0);
    
    HoloKitCameraData holokitCameraData;
    holokitCameraData.LeftViewportRect = leftViewportRect;
    holokitCameraData.RightViewportRect = rightViewportRect;
    holokitCameraData.NearClipPlane = nearClipPlane;
    holokitCameraData.FarClipPlane = farClipPlane;
    holokitCameraData.LeftProjectionMatrix = leftProjectionMatrix;
    holokitCameraData.RightProjectionMatrix = rightProjectionMatrix;
    holokitCameraData.CameraToCenterEyeOffset = cameraToCenterEyeOffset;
    holokitCameraData.CameraToScreenCenterOffset = cameraToScreenCenterOffset;
    holokitCameraData.CenterEyeToLeftEyeOffset = centerEyeToLeftEyeOffset;
    holokitCameraData.CenterEyeToRightEyeOffset = centerEyeToRightEyeOffset;
    return holokitCameraData;
}

@end

extern "C" {
    
float * HoloKitSDK_GetHoloKitCameraData(float ipd, float farClipPlane) {
    
    HoloKitModel holokitModel = [DeviceProfile getHoloKitModel:HoloKitX];
    HoloKitCameraData holokitCameraData = [StarManager getHoloKitCameraData:holokitModel ipd:ipd farClipPlane:farClipPlane];
    
    float *result = (float *)malloc(sizeof(float) * 54);
    result[0] = holokitCameraData.LeftViewportRect.x;
    result[1] = holokitCameraData.LeftViewportRect.y;
    result[2] = holokitCameraData.LeftViewportRect.z;
    result[3] = holokitCameraData.LeftViewportRect.w;
    result[4] = holokitCameraData.RightViewportRect.x;
    result[5] = holokitCameraData.RightViewportRect.y;
    result[6] = holokitCameraData.RightViewportRect.z;
    result[7] = holokitCameraData.RightViewportRect.w;
    result[8] = holokitCameraData.NearClipPlane;
    result[9] = holokitCameraData.FarClipPlane;
    for (int i = 10; i < 14; i++) {
        result[i] = holokitCameraData.LeftProjectionMatrix.columns[i - 10].x;
    }
    for (int i = 14; i < 18; i++) {
        result[i] = holokitCameraData.LeftProjectionMatrix.columns[i - 14].y;
    }
    for (int i = 18; i < 22; i++) {
        result[i] = holokitCameraData.LeftProjectionMatrix.columns[i - 18].z;
    }
    for (int i = 22; i < 26; i++) {
        result[i] = holokitCameraData.LeftProjectionMatrix.columns[i - 22].w;
    }
    for (int i = 26; i < 30; i++) {
        result[i] = holokitCameraData.RightProjectionMatrix.columns[i - 26].x;
    }
    for (int i = 30; i < 34; i++) {
        result[i] = holokitCameraData.RightProjectionMatrix.columns[i - 30].y;
    }
    for (int i = 34; i < 38; i++) {
        result[i] = holokitCameraData.RightProjectionMatrix.columns[i - 34].z;
    }
    for (int i = 38; i < 42; i++) {
        result[i] = holokitCameraData.RightProjectionMatrix.columns[i - 38].w;
    }
    result[42] = holokitCameraData.CameraToCenterEyeOffset.x;
    result[43] = holokitCameraData.CameraToCenterEyeOffset.y;
    result[44] = holokitCameraData.CameraToCenterEyeOffset.z;
    result[45] = holokitCameraData.CameraToScreenCenterOffset.x;
    result[46] = holokitCameraData.CameraToScreenCenterOffset.y;
    result[47] = holokitCameraData.CameraToScreenCenterOffset.z;
    result[48] = holokitCameraData.CenterEyeToLeftEyeOffset.x;
    result[49] = holokitCameraData.CenterEyeToLeftEyeOffset.y;
    result[50] = holokitCameraData.CenterEyeToLeftEyeOffset.z;
    result[51] = holokitCameraData.CenterEyeToRightEyeOffset.x;
    result[52] = holokitCameraData.CenterEyeToRightEyeOffset.y;
    result[53] = holokitCameraData.CenterEyeToRightEyeOffset.z;
    
    return result;
}
    
void HoloKitSDK_ReleaseHoloKitCameraData(float *dataPtr) {
    free(dataPtr);
}

}
