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
#import "ar_session_manager.h"
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
    
    bool IsStereoscopicRendering() { return is_stereoscopic_rendering_; }
    
    void EnableStereoscopicRendering(bool value) { is_stereoscopic_rendering_ = value; }
    
    bool IsSinglePassRendering() { return is_single_pass_rendering_; }
    
    void EnableSinglePassRendering(bool value) { is_single_pass_rendering_ = value; }
    
    bool StartNfcSession();
    
    double GetLastSubmitCurrentFrameTime() { return last_submit_current_frame_time_; }
    
    void SetLastSubmitCurrentFrameTime(double time) { last_submit_current_frame_time_ = time; }
    
    double GetLastPopulateNextFrameTime() { return last_populate_next_frame_time_; }
    
    void SetLastPopulateNextFrameTime(double time) { last_populate_next_frame_time_ = time; }
    
    bool GetIsSkippingFrame() { return is_skipping_frame_; }
    
    void SetIsSkippingFrame(bool val) { is_skipping_frame_ = val; }
    
    NSString* GetDeviceName() { return device_name_; }

    NSString* GetModelName() { return model_name_; }
    
    static std::unique_ptr<HoloKitApi>& GetInstance();
    
private:
    
    /// @brief Initializes view matrix, projection matrix and viewport rectangles.
    void InitOpticalParameters();
    
private:
    
    /// @brief The model name of the machine.
    NSString* model_name_;
    
    /// @brief The device name of the machine.
    NSString* device_name_;
    
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
    
    ARSessionManager* ar_session_handler_ = nullptr;
    
    static std::unique_ptr<HoloKitApi> holokit_api_;
    
    bool is_initialized_ = false;
    
    /// @brief Whether stereoscopic rendering is open.
    bool is_stereoscopic_rendering_ = false;
    
    bool is_single_pass_rendering_ = false;
    
    double last_submit_current_frame_time_ = 0.0;
    
    double last_populate_next_frame_time_ = 0.0;
    
    bool is_skipping_frame_ = false;

}; // class HoloKitApi

std::unique_ptr<HoloKitApi> HoloKitApi::holokit_api_;

std::unique_ptr<HoloKitApi>& HoloKitApi::GetInstance() {
    return holokit_api_;
}

} // namespace holokit

