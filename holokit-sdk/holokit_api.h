//
//  holokit_xr_unity.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//
#pragma once

#import <vector>
#import <memory>

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>
#import "UnityXRTypes.h"
#import "ar_session.h"
#import "math_helpers.h"
#import "holokit_profile.h"
#import "nfc_session.h"

namespace holokit {

class HoloKitApi {
    
public:
    HoloKitApi() {};
    
    void Initialize();
    
    simd_float4x4 GetCurrentCameraTransform();
    
    simd_float3 GetEyePosition(int eye_index);
    
    simd_float4x4 GetProjectionMatrix(int eye_index);
    
    simd_float4 GetViewportRect(int eye_index);
    
    float GetHorizontalAlignmentMarkerOffset() { return horizontal_alignment_marker_offset_; }
    
    simd_float3 GetCameraToCenterEyeOffset() { return camera_to_center_eye_offset_; }
    
    bool GetIsInitialized() { return is_initialized_; }
    
    int GetScreenWidth() { return screen_width_; }
    
    int GetScreenHeight() { return screen_height_; }
    
    bool GetStereoscopicRendering() { return stereoscopic_rendering_; }
    
    void SetStereoscopicRendering(bool val);
    
    bool GetSinglePassRendering() { return single_pass_rendering_; }
    
    void SetSinglePassRendering(bool val) { single_pass_rendering_ = val; }

    NSString* GetModelName() { return model_name_; }
    
    const float kUserInterpupillaryDistance = 0.064;
    
    static std::unique_ptr<HoloKitApi>& GetInstance();
    
private:
    
    /// @brief Initializes view matrix, projection matrix and viewport rectangles.
    void InitOpticalParameters();
    
private:
    
    /// @brief The model name of the machine.
    NSString* model_name_;
    
    /// @brief Stores left and right eye projection matrices.
    std::vector<simd_float4x4> projection_matrices_;
    
    /// @brief Stores left and right eye viewport rects.
    /// @details x is original x, y is original y, z is width and w is height.
    std::vector<simd_float4> viewport_rects_;
    
    /// @brief Relative eye position from the camera to both eyes.
    std::vector<simd_float3> eye_positions_;
    
    /// @brief Screen width in pixels.
    int screen_width_;
    
    /// @brief Screen height in pixels. 
    int screen_height_;
    
    float horizontal_alignment_marker_offset_;
    
    /// @brief The vector from camera pointing to the center of the eyes.
    simd_float3 camera_to_center_eye_offset_;
    
    static std::unique_ptr<HoloKitApi> holokit_api_;
    
    bool is_initialized_ = false;
    
    /// @brief Whether stereoscopic rendering is open.
    bool stereoscopic_rendering_ = false;
    
    bool single_pass_rendering_ = false;
}; // class HoloKitApi

} // namespace holokit

