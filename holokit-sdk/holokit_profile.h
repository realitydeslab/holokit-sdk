//
//  holokit_profile.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//

#include <simd/simd.h>

namespace holokit {

class Profile{

public:
    // All vectors are in right-handed ARKit coordinate system.
    typedef struct PhoneModel {
        float screenWidth;
        float screenHeight;
        float screenBottom;
        float centerLineOffset;
        // The 3D offset vector from center of the camera to the center of the display area's bottomline. (in meters)
        simd_float3 cameraOffset;
        // resolution in pixel
        int screenResolutionWidth;
        int screenResolutionHeight;
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
    
    enum PhoneType {
        iPhone11,
        iPhone11Pro,
        iPhone11ProMax,
        iPhone12Mini,
        iPhone12,
        iPhone12Pro,
        iPhone12ProMax,
        iPadPro2020,
        iPadPro2021,
        UnknownPhoneType
    };
    
    enum HoloKitType {
        HoloKitX,
        UnknownHoloKitType
    };
    
    static PhoneModel GetPhoneModel(PhoneType type);
    
    // Currently there is only one HoloKit model.
    static HoloKitModel GetHoloKitModel(HoloKitType type);
    
    static PhoneType DeviceNameToPhoneType(NSString* device_name);
    
}; // class
} // namespace
