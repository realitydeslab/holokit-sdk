//
//  holokit_xr_unity.cpp
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include "holokit_xr_unity.h"
#include <sys/utsname.h>

const float kUserInterpupillaryDistance = 0.064;

namespace holokit {

void HoloKitApi::Initialize() {
    NSLog(@"[HoloKitApi]: Initialize()");
    
    // TODO: do this more elegantly
    width_ = 2778;
    height_ = 1284;
    
    // Retrive device model
    // see: https://stackoverflow.com/questions/9617301/how-to-print-out-string-constant-with-nslog-on-ios
    struct utsname system_info;
    uname(&system_info);
    NSString* device_name = [NSString stringWithCString:system_info.machine encoding:NSUTF8StringEncoding];
    NSLog(@"device name %@", device_name);
    
    InitOpticalParameters();
    
    ar_session_handler_ = [ARSessionDelegateController sharedARSessionDelegateController];
}

PhoneModel HoloKitApi::InitPhoneModel() {
    // iPhone12ProMax phone model
    PhoneModel phone_model;
    phone_model.screenWidth = 0.15390;
    phone_model.screenHeight = 0.07113;
    phone_model.screenBottom = 0.00347;
    phone_model.centerLineOffset = 0.0;
    phone_model.cameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
    
    return phone_model;
}

HoloKitModel HoloKitApi::InitHoloKitModel() {
    HoloKitModel holokit_model;
    holokit_model.opticalAxisDistance = 0.064;
    holokit_model.mrOffset = simd_make_float3(0, -0.02894, 0.07055);
    holokit_model.distortion = 0.0;
    holokit_model.viewportInner = 0.0292;
    holokit_model.viewportOuter = 0.0292;
    holokit_model.viewportTop = 0.02386;
    holokit_model.viewportBottom = 0.02386;
    holokit_model.focalLength = 0.065;
    holokit_model.screenToLens = 0.02715 + 0.03136 + 0.002;
    holokit_model.lensToEye = 0.02497 + 0.03898;
    holokit_model.axisToBottom = 0.02990;
    holokit_model.viewportCushion = 0.0000;
    holokit_model.horizontalAlignmentMarkerOffset = 0.05075;
    
    return holokit_model;
}

void HoloKitApi::InitOpticalParameters() {
    auto phone = InitPhoneModel();
    auto model = InitHoloKitModel();
    
    // projection matrices
    float center_x = 0.5 * phone.screenWidth + phone.centerLineOffset;
    float center_y = phone.screenHeight - (model.axisToBottom - phone.screenBottom);
    float full_width = model.viewportOuter * 2 + model.opticalAxisDistance + model.viewportCushion * 2;
    float width = model.viewportOuter + model.viewportInner + model.viewportCushion * 2;
    float height = model.viewportTop + model.viewportBottom + model.viewportCushion * 2;
    float ipd = kUserInterpupillaryDistance;
    float near = model.lensToEye;
    float far = 1000.0f;
    
    simd_float4x4 left_projection_matrix;
    left_projection_matrix.columns[0].x = 2 * near / width;
    left_projection_matrix.columns[1].y = 2 * near / height;
    left_projection_matrix.columns[2].x = (full_width - ipd - width) / width;
    left_projection_matrix.columns[2].y = (model.viewportTop - model.viewportBottom) / height;
    left_projection_matrix.columns[2].z = -(far + near) / (far - near);
    left_projection_matrix.columns[3].z = -(2.0 * far * near) / (far - near);
    left_projection_matrix.columns[2].w = -1.0;
    left_projection_matrix.columns[3].w = 0.0;
    
    simd_float4x4 right_projection_matrix = left_projection_matrix;
    right_projection_matrix.columns[2].x = -right_projection_matrix.columns[2].x;
    
    projection_matrices_.resize(2);
    projection_matrices_[0] = left_projection_matrix;
    projection_matrices_[1] = right_projection_matrix;
    
    // viewport rects
    double y_min_in_pixel = (double)((center_y - (model.viewportTop + model.viewportCushion)) / phone.screenHeight * (float)height_);
    double x_min_right_in_pixel = (double)((center_x + full_width / 2 - width) / phone.screenWidth * (float)width_);
    double x_min_left_in_pixel = (double)((center_x - full_width / 2) / phone.screenWidth * (float)width_);
    double width_in_pixel = (double)(width / phone.screenWidth * (float)width_);
    double height_in_pixel = (double)(height / phone.screenHeight * (float)height_);
    
    simd_float4 leftRect;
    leftRect.x = x_min_left_in_pixel / width_;
    leftRect.z = width_in_pixel / width_;
    leftRect.w = height_in_pixel / height_;
    leftRect.y = 1 - y_min_in_pixel / height_ - leftRect.w;
    simd_float4 rightRect;
    rightRect.x = x_min_right_in_pixel / width_;
    rightRect.z = width_in_pixel / width_;
    rightRect.w = height_in_pixel / height_;
    rightRect.y = 1 - y_min_in_pixel / height_ - rightRect.w;
    
    viewport_rects_.resize(2);
    viewport_rects_[0] = leftRect;
    viewport_rects_[1] = rightRect;
    
    // view matrix
    simd_float3 offset = phone.cameraOffset + model.mrOffset;
    eye_positions_.resize(2);
    eye_positions_[0] = simd_make_float3(offset.x - ipd / 2, offset.y, -offset.z);
    eye_positions_[1] = simd_make_float3(offset.x + ipd / 2, offset.y, -offset.z);
    
    // horizontal alignment marker offset
    horizontal_alignment_marker_offset_ = 0.5 + (phone.centerLineOffset + model.horizontalAlignmentMarkerOffset) / phone.screenWidth;
}

simd_float4x4 HoloKitApi::GetProjectionMatrix(int eye_index) {
    if(eye_index == 0) {
        return projection_matrices_[0];
    } else if (eye_index == 1) {
        return projection_matrices_[1];
    }
    NSLog(@"[HoloKitApi]: projection matrices are not initialized.");
    return matrix_identity_float4x4;
}

simd_float4 HoloKitApi::GetViewportRect(int eye_index) {
    if(eye_index == 0) {
        return viewport_rects_[0];
    } else if (eye_index == 1) {
        return viewport_rects_[1];
    }
    NSLog(@"[HoloKitApi]: viewport rects are not initialized.");
    return simd_make_float4(0);
}

simd_float3 HoloKitApi::GetEyePosition(int eye_index) {
    if(eye_index == 0) {
        return eye_positions_[0];
    } else if (eye_index == 1) {
        return eye_positions_[1];
    }
    NSLog(@"[HoloKitApi]: eye positions are not initialized.");
    return simd_make_float3(0);
}

} // namespace
