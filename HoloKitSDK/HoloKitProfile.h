//
//  HoloKitProfile.h
//  holokit
//
//  Created by Yuchen Zhang on 2022/7/18.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

typedef enum {
    HoloKitX = 0
} HoloKitType;

typedef enum {
    iPhoneXS = 0,
    iPhoneXSMax = 1,
    iPhone11Pro = 2,
    iPhone11ProMax = 3,
    iPhone12 = 4,
    iPhone12Pro = 5,
    iPhone12ProMax = 6,
    iPhone13 = 7,
    iPhone13Pro = 8,
    iPhone13ProMax = 9,
    iPad = 10, // all iPads are the same to us
    Unknown = 11
} PhoneType;

typedef struct {
    // Distance beetween eyes
    float OpticalAxisDistance;
    
    // 3D offset from the center of bottomline of the holokit phone display to the center of two eyes.
    simd_float3 MrOffset;
    
    // Eye view area width
    float ViewportInner;
    
    // Eye view area height
    float ViewportOuter;
    
    // Eye view area spillter width
    float ViewportTop;
    
    // Eye view area spillter width
    float ViewportBottom;
    
    // Fresnel lens focal length
    float FocalLength;
    
    // Screen To Fresnel distance
    float ScreenToLens;
    
    // Fresnel To eye distance
    float LensToEye;
    
    // Bottom of the holder to bottom of the view
    float AxisToBottom;
    
    // The distance between the center of the HME and the marker
    float HorizontalAlignmentMarkerOffset;
} HoloKitModel;

typedef struct {
    // The long screen edge of the phone
    float ScreenWidth;
    
    // The short screen edge of the phone
    float ScreenHeight;
    
    // The distance from the bottom of display area to the touching surface of the holokit phone holder
    float ScreenBottom;
    
    // The distance from the center of the display to the rendering center
    //float CenterLineOffset;
    
    // The 3D offset vector from center of the camera to the center of the display area's bottomline
    simd_float3 CameraOffset;
} PhoneModel;

@interface HoloKitProfile : NSObject

+ (HoloKitModel)getHoloKitModel:(HoloKitType)holokitType;

+ (PhoneModel)getPhoneModel;

@end
