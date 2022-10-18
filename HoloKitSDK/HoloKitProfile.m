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
    } else if ([deviceName isEqualToString:@"iPhone13,2"]) {
        return iPhone12;
    } else if ([deviceName isEqualToString:@"iPhone13,3"]) {
        return iPhone12Pro;
    } else if ([deviceName isEqualToString:@"iPhone13,4"]) {
        return iPhone12ProMax;
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
        return iPhone13ProMax;
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
            break;
        case iPhoneXSMax:
            phoneModel.ScreenWidth = 0.14971;
            phoneModel.ScreenHeight = 0.06961;
            phoneModel.ScreenBottom = 0.00391;
            phoneModel.CameraOffset = simd_make_float3(0.06694, -0.09405, -0.00591);
            break;
        case iPhone11Pro:
            phoneModel.ScreenWidth = 0.13495;
            phoneModel.ScreenHeight = 0.06233;
            phoneModel.ScreenBottom = 0.00452;
            phoneModel.CameraOffset = simd_make_float3(0.05996, -0.02364 - 0.03494, -0.00591);
            break;
        case iPhone11ProMax:
            phoneModel.ScreenWidth = 0.14891;
            phoneModel.ScreenHeight = 0.06881;
            phoneModel.ScreenBottom = 0.00452;
            phoneModel.CameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
            break;
        case iPhone12:
        case iPhone12Pro:
        case iPhone13:
        case iPhone13Pro:
        case iPhone14:
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.05996, -0.02364 - 0.03494, -0.00591);
            break;
        case iPhone12ProMax:
        case iPhone13ProMax:
        case iPhone14Plus:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
            break;
        case iPhone14Pro: // TODO: Not correct
            phoneModel.ScreenWidth = 0.13977;
            phoneModel.ScreenHeight = 0.06458;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.05996, -0.02364 - 0.03494, -0.00591);
            break;
        case iPhone14ProMax: // TODO: Not correct
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
            break;
        case iPad:
        case Unknown:
        default:
            phoneModel.ScreenWidth = 0.15390;
            phoneModel.ScreenHeight = 0.07113;
            phoneModel.ScreenBottom = 0.00347;
            phoneModel.CameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
            break;
    }
    return phoneModel;
}

@end
