//
//  holokit_xr_unity.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//
#pragma once

#include <vector>
#include <memory>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <simd/simd.h>
#include "UnityXRTypes.h"
#include "ar_session.h"
#include "math_helpers.h"
#include "holokit_profile.h"
#include "nfc_session.h"

namespace holokit {

/// Wrapper of HoloKit SDK
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
    
    ARSessionDelegateController* GetArSessionHandler() { return ar_session_handler_; }
    
    bool GetIsXrModeEnabled() { return is_xr_mode_enabled_; }
    
    bool GetIsInitialized() { return is_initialized_; }
    
    /// @brief This method might fail due to NFC check, in which case it returns false.
    bool SetIsXrModeEnabled(bool val);
    
    static std::unique_ptr<HoloKitApi>& GetInstance();
    
private:
    
    /// @brief Initializes view matrix, projection matrix and viewport rectangles.
    void InitOpticalParameters();
    
    /// @brief Gets the phone model of the device.
    void GetDeviceModel();
    
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
    int screen_width_;
    
    /// @brief Screen height in pixels. 
    int screen_height_;
    
    float horizontal_alignment_marker_offset_;
    
    /// @brief The vector from camera pointing to the center of the eyes.
    simd_float3 camera_to_center_eye_offset_;
    
    ARSessionDelegateController* ar_session_handler_ = nullptr;
    
    /// @brief True for XR mode and false for AR mode.
    bool is_xr_mode_enabled_;
    
    /// @brief If this value is true, the app will do NFC check when the user switches to XR mode.
    bool is_nfc_enabled_;
    
    bool is_nfc_validated_;
    
    static std::unique_ptr<HoloKitApi> holokit_api_;
    
    bool is_initialized_ = false;
    
}; // class HoloKitApi

std::unique_ptr<HoloKitApi> HoloKitApi::holokit_api_;

std::unique_ptr<HoloKitApi>& HoloKitApi::GetInstance() {
    return holokit_api_;
}

} // namespace holokit
