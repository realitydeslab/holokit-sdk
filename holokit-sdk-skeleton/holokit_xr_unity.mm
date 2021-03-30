//
//  holokit_xr_unity.cpp
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include "holokit_xr_unity.h"

const float kUserInterpupillaryDistance = 0.064;

namespace holokit {

void HoloKitApi::Initialize() {
    NSLog(@"[HoloKitApi]: Initialize()");
    // Initializes phone model and holokit model
    auto phone_model = InitPhoneModel();
    auto holokit_model = InitHoloKitModel();
    mrOffset_ = holokit_model.mrOffset;
    cameraOffset_ = phone_model.cameraOffset;
    
    // TODO: do this more elegantly
    width_ = 2778;
    height_ = 1284;
    
    ComputeProjectionMatrices();
    ComputeViewportRects();
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

void HoloKitApi::ComputeProjectionMatrices() {
    //auto& phone = phone_model_;
    auto hme = InitHoloKitModel();
    
    //float center_x = 0.5 * phone.screenWidth + phone.centerLineOffset;
    //float center_y = phone.screenHeight - (hme.axisToBottom - phone.screenBottom);
    float full_width = hme.viewportOuter * 2 + hme.opticalAxisDistance + hme.viewportCushion * 2;
    float width = hme.viewportOuter + hme.viewportInner + hme.viewportCushion * 2;
    float height = hme.viewportTop + hme.viewportBottom + hme.viewportCushion * 2;
    float ipd = kUserInterpupillaryDistance;
    float near = hme.lensToEye;
    float far = 1000.0f;
    
    UnityXRMatrix4x4 leftProjMatrix{};
    leftProjMatrix.columns[0].x = 2 * near / width;
    leftProjMatrix.columns[1].y = 2 * near / height;
    leftProjMatrix.columns[2].x = (full_width - ipd - width) / width;
    leftProjMatrix.columns[2].y = (hme.viewportTop - hme.viewportBottom) / height;
    leftProjMatrix.columns[2].z = -(far + near) / (far - near);
    leftProjMatrix.columns[3].z = -(2.0 * far * near) / (far - near);
    leftProjMatrix.columns[2].w = -1.0;
    leftProjMatrix.columns[3].w = 0.0;
    
    UnityXRMatrix4x4 rightProjMatrix = leftProjMatrix;
    rightProjMatrix.columns[2].x = -rightProjMatrix.columns[2].x;
    
    projection_matrices_.resize(2);
    projection_matrices_[0] = leftProjMatrix;
    projection_matrices_[0] = rightProjMatrix;
}

void HoloKitApi::ComputeViewportRects() {
    auto phone = InitPhoneModel();
    auto hme = InitHoloKitModel();
    
    float center_x = 0.5 * phone.screenWidth + phone.centerLineOffset;
    float center_y = phone.screenHeight - (hme.axisToBottom - phone.screenBottom);
    float full_width = hme.viewportOuter * 2 + hme.opticalAxisDistance + hme.viewportCushion * 2;
    float width = hme.viewportOuter + hme.viewportInner + hme.viewportCushion * 2;
    float height = hme.viewportTop + hme.viewportBottom + hme.viewportCushion * 2;
    
    double y_min_in_pixel = (double)((center_y - (hme.viewportTop + hme.viewportCushion)) / phone.screenHeight * (float)height_);
    double x_min_right_in_pixel = (double)((center_x + full_width / 2 - width) / phone.screenWidth * (float)width_);
    double x_min_left_in_pixel = (double)((center_x - full_width / 2) / phone.screenWidth * (float)width_);
    double width_in_pixel = (double)(width / phone.screenWidth * (float)width_);
    double height_in_pixel = (double)(height / phone.screenHeight * (float)height_);
    
    UnityXRRectf leftRect{};
    leftRect.x = x_min_left_in_pixel / width_;
    leftRect.width = width_in_pixel / width_;
    leftRect.height = height_in_pixel / height_;
    leftRect.y = 1 - y_min_in_pixel / height_ - leftRect.height;
    UnityXRRectf rightRect{};
    rightRect.x = x_min_right_in_pixel / width_;
    rightRect.width = width_in_pixel / width_;
    rightRect.height = height_in_pixel / height_;
    rightRect.y = 1 - y_min_in_pixel / height_ - rightRect.height;
    
    viewport_rects_.resize(2);
    viewport_rects_[0] = leftRect;
    viewport_rects_[1] = rightRect;
}

UnityXRMatrix4x4 HoloKitApi::GetProjectionMatrix(int eye_index) {
    if(eye_index == 0) {
        return projection_matrices_[0];
    } else if (eye_index == 1) {
        return projection_matrices_[1];
    } else {
        NSLog(@"[HoloKitApi]: projection matrices are not initialized.");
        return UnityXRMatrix4x4{};
    }
    return UnityXRMatrix4x4{};
}

UnityXRRectf HoloKitApi::GetViewportRect(int eye_index) {
    if(eye_index == 0) {
        return viewport_rects_[0];
    } else if (eye_index == 1) {
        return viewport_rects_[1];
    } else {
        NSLog(@"[HoloKitApi]: viewport rects are not initialized.");
        return UnityXRRectf{};
    }
    return UnityXRRectf{};
}

UnityXRPose HoloKitApi::GetViewMatrix(int eye_index) {
    // use fake data temporarily
    UnityXRPose pose{};
    if(eye_index == 0) {
        pose.position.x = -1.0f;
    } else if (eye_index == 1) {
        pose.position.x = 1.0f;
    }
    pose.position.z = 0.0f;
    pose.rotation.w = 1.0f;
    return pose;
}

} // namespace
