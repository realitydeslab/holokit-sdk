//
//  holokit_profile.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//

#import <Foundation/Foundation.h>
#include "holokit_profile.h"

#define CASE(str)                       if ([__s__ isEqualToString:(str)])
#define SWITCH(s)                       for (NSString *__s__ = (s); ; )
#define DEFAULT

namespace holokit {
    
    Profile::PhoneModel Profile::GetPhoneModel(PhoneType type) {
        PhoneModel phone_model;
        switch(type) {
            case(iPhone11):
                //NSLog(@"Profile::iPhone11");
                phone_model.screenWidth = 0.13978f;
                phone_model.screenHeight = 0.06458f;
                phone_model.screenBottom = 0.00557f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.06318f, -0.05787f, 0.00988f);
                phone_model.screenResolutionWidth = 1792;
                phone_model.screenResolutionHeight = 828;
                break;
            case(iPhone11Pro):
                //NSLog(@"Profile::iPhone11Pro");
                phone_model.screenWidth = 0.13495f;
                phone_model.screenHeight = 0.06233f;
                phone_model.screenBottom = 0.00452f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.05996f, -0.02364f - 0.03494f, 0.00591f);
                phone_model.screenResolutionWidth = 2436;
                phone_model.screenResolutionHeight = 1125;
                break;
            case(iPhone11ProMax):
                //NSLog(@"Profile::iPhone11ProMax");
                phone_model.screenWidth = 0.14891f;
                phone_model.screenHeight = 0.06881f;
                phone_model.screenBottom = 0.00452f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.066945f, -0.061695f, 0.0091f);
                phone_model.screenResolutionWidth = 2688;
                phone_model.screenResolutionHeight = 1242;
                break;
            case(iPhone12Mini):
                //NSLog(@"Profile::iPhone12Mini");
                phone_model.screenWidth = 0.12496f;
                phone_model.screenHeight = 0.05767f;
                phone_model.screenBottom = 0.00327f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.06318f, -0.05787f, 0.00988f);
                phone_model.screenResolutionWidth = 2340;
                phone_model.screenResolutionHeight = 1080;
                break;
            case(iPhone12):
                //NSLog(@"Profile::iPhone12");
                phone_model.screenWidth = 0.13977f;
                phone_model.screenHeight = 0.06458f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.05996f, -0.02364f - 0.03494f, 0.00591f);
                phone_model.screenResolutionWidth = 2532;
                phone_model.screenResolutionHeight = 1170;
                break;
            case(iPhone12Pro):
                //NSLog(@"Profile::iPhone12Pro");
                phone_model.screenWidth = 0.13977f;
                phone_model.screenHeight = 0.06458f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.05996f, -0.02364f - 0.03494f, 0.00591f);
                phone_model.screenResolutionWidth = 2532;
                phone_model.screenResolutionHeight = 1170;
                break;
            case(iPhone12ProMax):
                //NSLog(@"Profile::iPhone12ProMax");
                phone_model.screenWidth = 0.15390f;
                phone_model.screenHeight = 0.07113f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.0495f, -0.061695f, 0.0091f);
                phone_model.screenResolutionWidth = 2778;
                phone_model.screenResolutionHeight = 1284;
                break;
            case(iPhone13Mini):
                //NSLog(@"Profile::iPhone13Mini");
                phone_model.screenWidth = 0.12496f;
                phone_model.screenHeight = 0.05767f;
                phone_model.screenBottom = 0.00327f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.06318f, -0.05787f, 0.00988f);
                phone_model.screenResolutionWidth = 2340;
                phone_model.screenResolutionHeight = 1080;
                break;
            case(iPhone13):
                //NSLog(@"Profile::iPhone13");
                phone_model.screenWidth = 0.13977f;
                phone_model.screenHeight = 0.06458f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.05996f, -0.02364f - 0.03494f, 0.00591f);
                phone_model.screenResolutionWidth = 2532;
                phone_model.screenResolutionHeight = 1170;
                break;
            case(iPhone13Pro):
                //NSLog(@"Profile::iPhone13Pro");
                phone_model.screenWidth = 0.13977f;
                phone_model.screenHeight = 0.06458f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.05996f, -0.02364f - 0.03494f, 0.00591f);
                phone_model.screenResolutionWidth = 2532;
                phone_model.screenResolutionHeight = 1170;
                break;
            case(iPhone13ProMax):
                //NSLog(@"Profile::iPhone13ProMax");
                phone_model.screenWidth = 0.15390f;
                phone_model.screenHeight = 0.07113f;
                phone_model.screenBottom = 0.00347f;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.0495f, -0.061695f, 0.0091f);
                phone_model.screenResolutionWidth = 2778;
                phone_model.screenResolutionHeight = 1284;
                break;
            case(iPadPro2020):
                //NSLog(@"Profile::iPadPro2020");
                phone_model.screenWidth = 0.0;
                phone_model.screenHeight = 0.0f;
                phone_model.screenBottom = 0.0;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.0f, 0.0f, 0.0f);
                phone_model.screenResolutionWidth = 2388;
                phone_model.screenResolutionHeight = 1668;
                break;
            case(iPadPro2021):
                //NSLog(@"Profile::iPadPro2021");
                phone_model.screenWidth = 0.0;
                phone_model.screenHeight = 0.0f;
                phone_model.screenBottom = 0.0;
                phone_model.centerLineOffset = 0.0f;
                phone_model.cameraOffset = simd_make_float3(0.0f, 0.0f, 0.0f);
                phone_model.screenResolutionWidth = 2732;
                phone_model.screenResolutionHeight = 2048;
                break;
            default:
                break;
        }
        return phone_model;
    }
    
    Profile::HoloKitModel Profile::GetHoloKitModel(HoloKitType type) {
        HoloKitModel holokit_model;
        switch(type) {
            case(HoloKitX):
                holokit_model.opticalAxisDistance = 0.064f;
                holokit_model.mrOffset = simd_make_float3(0.0f, -0.02894f, 0.07055f);
                holokit_model.distortion = 0.0f;
                holokit_model.viewportInner = 0.0292f;
                holokit_model.viewportOuter = 0.0292f;
                holokit_model.viewportTop = 0.02386f;
                holokit_model.viewportBottom = 0.02386f;
                holokit_model.focalLength = 0.065f;
                holokit_model.screenToLens = 0.02715f + 0.03136f + 0.002f;
                holokit_model.lensToEye = 0.02497f + 0.03898f;
                holokit_model.axisToBottom = 0.02990f;
                holokit_model.viewportCushion = 0.0000f;
                holokit_model.horizontalAlignmentMarkerOffset = 0.05075f;
                break;
            default:
                break;
        }
        return holokit_model;
    }
    
    Profile::PhoneType Profile::ModelNameToPhoneType(NSString* model_name) {
        PhoneType phone_type;
        SWITCH (model_name) {
            CASE (@"iPhone12,1") {
                phone_type = iPhone11;
                break;
            }
            CASE (@"iPhone12,3") {
                phone_type = iPhone11Pro;
                break;
            }
            CASE (@"iPhone12,5") {
                phone_type = iPhone11ProMax;
                break;
            }
            CASE (@"iPhone13,1") {
                phone_type = iPhone12Mini;
                break;
            }
            CASE (@"iPhone13,2") {
                phone_type = iPhone12;
                break;
            }
            CASE (@"iPhone13,3") {
                phone_type = iPhone12Pro;
                break;
            }
            CASE (@"iPhone13,4") {
                phone_type = iPhone12ProMax;
                break;
            }
            CASE (@"iPad8,9") {
                phone_type = iPadPro2020;
                break;
            }
            CASE (@"iPad13,8") {
                phone_type = iPadPro2021;
                break;
            }
            CASE (@"iPhone14,2") {
                phone_type = iPhone13Pro;
                break;
            }
            CASE (@"iPhone14,3") {
                phone_type = iPhone13ProMax;
                break;
            }
            CASE (@"iPhone14,4") {
                phone_type = iPhone13Mini;
                break;
            }
            CASE (@"iPhone14,5") {
                phone_type = iPhone13;
                break;
            }
            DEFAULT {
                phone_type = UnknownPhoneType;
                break;
            }
         }
        return phone_type;
    }
}
