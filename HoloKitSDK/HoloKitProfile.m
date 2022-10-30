//
//  HoloKitProfile.m
//  holokit-sdk
//
//  Created by Yuchen Zhang on 2022/7/18.
//

#import "HoloKitProfile.h"
#import <sys/utsname.h>

@interface HoloKitProfile()

@end

@implementation HoloKitProfile

+ (HoloKitModel)getHoloKitModel:(HoloKitType)holokitType {
    HoloKitModel holokitModel;
    switch (holokitType) {
        case HoloKitX:
            holokitModel.OpticalAxisDistance = 0.064;
            holokitModel.MrOffset = simd_make_float3(0, -0.02894, -0.07055);
            holokitModel.ViewportInner = 0.0292;
            holokitModel.ViewportOuter = 0.0292;
            holokitModel.ViewportTop = 0.02386;
            holokitModel.ViewportBottom = 0.02386;
            holokitModel.FocalLength = 0.065;
            holokitModel.ScreenToLens = 0.02715 + 0.03136 + 0.002;
            holokitModel.LensToEye = 0.02497 + 0.03898;
            holokitModel.AxisToBottom = 0.02990;
            holokitModel.HorizontalAlignmentMarkerOffset = 0.05075;
            break;
        default:
            break;
    }
    return holokitModel;
}

+ (PhoneType)getPhoneType {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if ([deviceName isEqualToString:@"iPhone11,2"]) {
        return iPhoneXS;
    } else if ([deviceName isEqualToString:@"iPhone11,4"] || [deviceName isEqualToString:@"iPhone11,6"]) {
        return iPhoneXSMax;
    } else if ([deviceName isEqualToString:@"iPhone12,3"]) {
        return iPhone11Pro;
    } else if ([deviceName isEqualToString:@"iPhone12,5"]) {
        return iPhone11ProMax;
    } else if ([deviceName isEqualToString:@"iPhone13,1"]) {
        return iPhone12mini;
    } else if ([deviceName isEqualToString:@"iPhone13,2"]) {
        return iPhone12;
    } else if ([deviceName isEqualToString:@"iPhone13,3"]) {
        return iPhone12Pro;
    } else if ([deviceName isEqualToString:@"iPhone13,4"]) {
        return iPhone12ProMax;
    } else if ([deviceName isEqualToString:@"iPhone14,4"]) {
        return iPhone13mini;
    } else if ([deviceName isEqualToString:@"iPhone14,5"]) {
        return iPhone13;
    } else if ([deviceName isEqualToString:@"iPhone14,2"]) {
        return iPhone13Pro;
    } else if ([deviceName isEqualToString:@"iPhone14,3"]) {
        return iPhone13ProMax;
    } else if ([deviceName isEqualToString:@"iPhone14,7"]) {
        return iPhone14;
    } else if ([deviceName isEqualToString:@"iPhone14,8"]) {
        return iPhone14Plus;
    } else if ([deviceName isEqualToString:@"iPhone15,2"]) {
        return iPhone14Pro;
    } else if ([deviceName isEqualToString:@"iPhone15,3"]) {
        return iPhone14ProMax;
    } else if ([deviceName isEqualToString:@"iPad13,8"] ||
               [deviceName isEqualToString:@"iPad13,9"] ||
               [deviceName isEqualToString:@"iPad13,10"] ||
               [deviceName isEqualToString:@"iPad13,11"]) {
        return iPad;
    } else {
        return Unknown;
    }
}

+ (PhoneModel)getPhoneModel {
    PhoneModel phoneModel;
    switch ([HoloKitProfile getPhoneType])
    {
        case iPhoneXS:
            phoneModel.ScreenWidth = 0.135097;
            phoneModel.ScreenHeight = 0.062391;
            phoneModel.ScreenBottom = 0.00391;
            phoneModel.CameraOffset = simd_make_float3(0.05986, -0.055215, -0.0091);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhoneXSMax:
            phoneModel.ScreenWidth = 0.14971;
            phoneModel.ScreenHeight = 0.06961;
            phoneModel.ScreenBottom = 0.00391;
            phoneModel.CameraOffset = simd_make_float3(0.06694, -0.09405, -0.00591);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone11Pro:
            phoneModel.ScreenWidth = 0.13495;
            phoneModel.ScreenHeight = 0.06233;
            phoneModel.ScreenBottom = 0.00452;
            phoneModel.CameraOffset = simd_make_float3(0.059955, -0.05932, -0.00591);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone11ProMax:
            phoneModel.ScreenWidth = 0.14891;
            phoneModel.ScreenHeight = 0.06881;
            phoneModel.ScreenBottom = 0.00452;
            phoneModel.CameraOffset = simd_make_float3(0.066935, -0.0658, -0.00591);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone12mini:
            phoneModel.ScreenWidth = 0.12496;
            phoneModel.ScreenHeight = 0.05767;
            phoneModel.ScreenBottom = 0.00327;
            phoneModel.CameraOffset = simd_make_float3(0.05508, -0.05354, -0.00620);
            phoneModel.ScreenDpi = 476;
            break;
        case iPhone12:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.060625, -0.05879, -0.00633);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone12Pro:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.061195, -0.05936, -0.00551);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone12ProMax:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.04952, -0.06464, -0.00591);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone13mini:
            phoneModel.ScreenWidth = 0.12496;
            phoneModel.ScreenHeight = 0.05767;
            phoneModel.ScreenBottom = 0.00327;
            phoneModel.CameraOffset = simd_make_float3(0.0549, -0.05336, -0.00633);
            phoneModel.ScreenDpi = 476;
            break;
        case iPhone13:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.06147, -0.05964, -0.00781);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone13Pro:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.042005, -0.05809, -0.00727);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone13ProMax:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.04907, -0.06464, -0.00727);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone14:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.061475, -0.05964, -0.00848);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone14Plus:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.06787, -0.06552, -0.00851);
            phoneModel.ScreenDpi = 458;
            break;
        case iPhone14Pro:
            phoneModel.ScreenWidth = 0.14109;
            phoneModel.ScreenHeight = 0.06508;
            phoneModel.ScreenBottom = 0.003185;
            phoneModel.CameraOffset = simd_make_float3(0.04021, -0.05717, -0.00784);
            phoneModel.ScreenDpi = 460;
            break;
        case iPhone14ProMax:
            phoneModel.ScreenWidth = 0.15434;
            phoneModel.ScreenHeight = 0.07121;
            phoneModel.ScreenBottom = 0.003185;
            phoneModel.CameraOffset = simd_make_float3(0.046835, -0.0633, -0.0078);
            phoneModel.ScreenDpi = 460;
            break;
        case iPad:
        case Unknown:
        default:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
            phoneModel.ScreenDpi = 460;
            break;
    }
    return phoneModel;
}

+ (BOOL)IsCurrentDeviceSupportedByHoloKit {
    PhoneType phoneType = [HoloKitProfile getPhoneType];
    return phoneType != Unknown;
}

+ (BOOL)IsCurrentDeviceIpad {
    PhoneType phoneType = [HoloKitProfile getPhoneType];
    return phoneType == iPad;
}

+ (BOOL)IsCurrentDeviceEquippedWithLiDAR {
    PhoneType phoneType = [HoloKitProfile getPhoneType];
    if (phoneType == iPhone12Pro) {
        return true;
    }
    if (phoneType == iPhone12ProMax) {
        return true;
    }
    if (phoneType == iPhone13Pro) {
        return true;
    }
    if (phoneType == iPhone13ProMax) {
        return true;
    }
    if (phoneType == iPhone14Pro) {
        return true;
    }
    if (phoneType == iPhone14ProMax) {
        return true;
    }
    return false;
}

@end
