//
//  HoloKitOptics.m
//  holokit-sdk
//
//  Created by Yuchen Zhang on 2022/7/18.
//

#import "HoloKitOptics.h"
#import <UIKit/UIKit.h>

@interface HoloKitOptics()

@end

@implementation HoloKitOptics

+ (HoloKitCameraData)getHoloKitCameraData:(HoloKitModel)holokitModel ipd:(float)ipd farClipPlane:(float)farClipPlane {
    PhoneModel phoneModel = [HoloKitProfile getPhoneModel];
    
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
    
    float alignmentMarkerOffset = holokitModel.HorizontalAlignmentMarkerOffset / phoneModel.ScreenWidth * [[UIScreen mainScreen] bounds].size.width;
    
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
    holokitCameraData.AlignmentMarkerOffset = alignmentMarkerOffset;
    return holokitCameraData;
}

@end
