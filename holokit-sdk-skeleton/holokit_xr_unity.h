//
//  holokit_xr_unity.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <vector>

#include "UnityXRTypes.h"
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>



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
    /// @brief Constructs a HoloKitApi.
    HoloKitApi() = default;
    
    /// @brief Destructor.
    ~HoloKitApi() = default;
    
    void Initialize();
    
    UnityXRPose GetViewMatrix(int eye_index);
    
    UnityXRMatrix4x4 GetProjectionMatrix(int eye_index);
    
    UnityXRRectf GetViewportRect(int eye_index);
    
private:
    void InitPhoneModel();
    
    void InitHoloKitModel();
    
    /// @brief Projection matrices only need to be computed once.
    void ComputeProjectionMatrices();
    
    /// @brief Viewport rects only need to be computed once.
    void ComputeViewportRects();
    
private:
    
    /// @brief Stores the optical data of the phone.
    PhoneModel phone_model_;
    
    /// @brief Stores the optical data of the holokit.
    HoloKitModel holokit_model_;
    
    /// @brief Stores left and right eye projection matrices.
    std::vector<UnityXRMatrix4x4> projection_matrices_;
    
    /// @brief Stores left and right eye viewport rects.
    std::vector<UnityXRRectf> viewport_rects_;
    
    /// @brief Screen width in pixels.
    int width_;
    
    /// @brief Screen height in pixels. 
    int height_;
    
}; // class HoloKitApi

} // namespace holokit
