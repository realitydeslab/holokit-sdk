//
//  holokit_xr_unity.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//
#pragma once

#include <vector>
#include <memory>

#include "UnityXRTypes.h"
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include "ar_session.mm"
#include "math_helpers.h"
#include <simd/simd.h>

namespace holokit {
    
typedef struct PhoneModel {
    float screenWidth;
    float screenHeight;
    float screenBottom;
    float centerLineOffset;
    simd_float3 cameraOffset;
} PhoneModel;

typedef struct HoloKitModel {
    float opticalAxisDistance;
    // 3D offset from the center of the bottomline of the HoloKit phone display to the center of two eyes
    // x is right
    // y is up
    // z is backward
    // right-handed
    simd_float3 mrOffset;
    float distortion;
    float viewportInner;
    float viewportOuter;
    float viewportTop;
    float viewportBottom;
    float focalLength;
    float screenToLens;
    float lensToEye;
    float axisToBottom;
    float viewportCushion;
    float horizontalAlignmentMarkerOffset;
} HoloKitModel;

/// Wrapper of HoloKit SDK
class HoloKitApi {
public:
    
    HoloKitApi() {};
    
    void Initialize();
    
    simd_float3 GetEyePosition(int eye_index);
    
    simd_float4x4 GetProjectionMatrix(int eye_index);
    
    simd_float4 GetViewportRect(int eye_index);
    
    float GetHorizontalAlignmentMarkerOffset() { return horizontal_alignment_marker_offset_; }
    
    static std::unique_ptr<HoloKitApi>& GetInstance();
    
private:
    PhoneModel InitPhoneModel();
    
    HoloKitModel InitHoloKitModel();
    
    /// @brief Initializes view matrix, projection matrix and viewport rectangles.
    void InitOpticalParameters();
    
private:
    
    /// @brief Stores left and right eye projection matrices.
    std::vector<simd_float4x4> projection_matrices_;
    
    /// @brief Stores left and right eye viewport rects.
    /// @details x is original x, y is original y, z is width and w is height.
    std::vector<simd_float4> viewport_rects_;
    
    /// @brief Relative eye position from the camera to both eyes.
    std::vector<simd_float3> eye_positions_;
    
    /// @brief Screen width in pixels.
    int width_;
    
    /// @brief Screen height in pixels. 
    int height_;
    
    float horizontal_alignment_marker_offset_;
    
    ARSessionDelegateController* ar_session_handler_;
    
    static std::unique_ptr<HoloKitApi> holokit_api_;
    
}; // class HoloKitApi

std::unique_ptr<HoloKitApi> HoloKitApi::holokit_api_;

std::unique_ptr<HoloKitApi>& HoloKitApi::GetInstance() {
    return holokit_api_;
}

} // namespace holokit
