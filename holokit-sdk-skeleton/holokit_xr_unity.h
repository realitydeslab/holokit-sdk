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
#include "holokit_profile.h"

namespace holokit {

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
    
    /// @brief Initializes view matrix, projection matrix and viewport rectangles.
    void InitOpticalParameters();
    
private:
    
    /// @brief The device name of the phone.
    NSString* device_name_;
    
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
