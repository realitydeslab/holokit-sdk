//
//  permissions.m
//  holokit-sdk
//
//  Created by Yuchen Zhang on 2022/4/21.
//

#import "permissions.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "holokit_sdk-Swift.h"
#import <UIKit/UIKit.h>

typedef void (*RequestCameraPermissionCompleted)(bool);
RequestCameraPermissionCompleted RequestCameraPermissionCompletedDelegate;

typedef void (*RequestMicrophonePermissionCompleted)(bool);
RequestMicrophonePermissionCompleted RequestMicrophonePermissionCompletedDelegate;

typedef void (*RequestPhotoLibraryAddPermissionCompleted)(int);
RequestPhotoLibraryAddPermissionCompleted RequestPhotoLibraryAddPermissionCompletedDelegate;

typedef void (*RequestLocalNetworkPermissionCompleted)(bool);
RequestLocalNetworkPermissionCompleted RequestLocalNetworkPermissionCompletedDelegate;

typedef void (*JumpToAppSettingsCompleted)(bool success);
JumpToAppSettingsCompleted JumpToAppSettingsCompletedDelegate;

typedef enum {
    PermissionStatusNotDetermined = 0,
    PermissionStatusRestricted = 1,
    PermissionStatusDenied = 2,
    PermissionStatusGranted = 3,
    PermissionStatusLimited = 4
} PermissionStatus;

@interface Permissions ()

@end

@implementation Permissions

+ (id)sharedInstance {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (PermissionStatus)getCameraPermissionStatus {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    return (PermissionStatus)status;
}

- (void)requestCameraPermission {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (RequestCameraPermissionCompletedDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RequestCameraPermissionCompletedDelegate(granted);
            });
        }
    }];
}

- (PermissionStatus)getMicrophonePermissionStatus {
    AVAudioSessionRecordPermission status = [[AVAudioSession sharedInstance] recordPermission];
    switch (status) {
        case AVAudioSessionRecordPermissionUndetermined:
            return PermissionStatusNotDetermined;
        case AVAudioSessionRecordPermissionDenied:
            return PermissionStatusDenied;
        case AVAudioSessionRecordPermissionGranted:
            return PermissionStatusGranted;
    }
}

- (void)requestMicrophonePermission {
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (RequestMicrophonePermissionCompletedDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RequestMicrophonePermissionCompletedDelegate(granted);
            });
        }
    }];
}

- (PermissionStatus)getPhotoLibraryAddPermissionStatus {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    return (PermissionStatus)status;
}

- (void)requestPhotoLibraryAddPermission {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (RequestPhotoLibraryAddPermissionCompletedDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RequestPhotoLibraryAddPermissionCompletedDelegate((int)status);
            });
        }
    }];
}

- (BOOL)isLocalNetworkPermissionNotDetermined {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    return ![prefs boolForKey:@"LocalNetworkPermissionDetermined"];
}

- (void)requestLocalNetworkPermission {
    LocalNetworkPermission *permission = [[LocalNetworkPermission alloc] init];
    [permission requestPermissionWithCompletion:^(BOOL granted) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (![prefs boolForKey:@"LocalNetworkPermissionDetermined"]){
            [prefs setBool:YES forKey:@"LocalNetworkPermissionDetermined"];
        }
        
        if (RequestLocalNetworkPermissionCompletedDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RequestLocalNetworkPermissionCompletedDelegate(granted);
            });
        }
    }];
}

- (void)jumpToAppSettings {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: UIApplicationOpenSettingsURLString] options:@{} completionHandler:^(BOOL success) {
        NSLog(@"[permissions] jump to app settings completed with %d", success);
        if (JumpToAppSettingsCompletedDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                JumpToAppSettingsCompletedDelegate(success);
            });
        }
    }];
}

@end

#pragma mark - extern "C"

int Permissions_GetCameraPermissionStatus(void) {
    return (int)[[Permissions sharedInstance] getCameraPermissionStatus];
}

void Permissions_SetRequestCameraPermissionCompletedDelegate(RequestCameraPermissionCompleted callback) {
    RequestCameraPermissionCompletedDelegate = callback;
}

void Permissions_RequestCameraPermission(void) {
    [[Permissions sharedInstance] requestCameraPermission];
}

int Permissions_GetMicrophonePermissionStatus(void) {
    return (int)[[Permissions sharedInstance] getMicrophonePermissionStatus];
}

void Permissions_SetRequestMicrophonePermissionCompletedDelegate(RequestMicrophonePermissionCompleted callback) {
    RequestMicrophonePermissionCompletedDelegate = callback;
}

void Permissions_RequestMicrophonePermission(void) {
    [[Permissions sharedInstance] requestMicrophonePermission];
}

int Permissions_GetPhotoLibraryAddPermissionStatus(void) {
    return (int)[[Permissions sharedInstance] getPhotoLibraryAddPermissionStatus];
}

void Permissions_SetRequestPhotoLibraryAddPermissionCompletedDelegate(RequestPhotoLibraryAddPermissionCompleted callback) {
    RequestPhotoLibraryAddPermissionCompletedDelegate = callback;
}

void Permissions_RequestPhotoLibraryAddPermission(void) {
    [[Permissions sharedInstance] requestPhotoLibraryAddPermission];
}

bool Permissions_IsLocalNetworkPermissionNotDetermined(void) {
    return [[Permissions sharedInstance] isLocalNetworkPermissionNotDetermined];
}

void Permissions_SetRequestLocalNetworkPermissionCompletedDelegate(RequestLocalNetworkPermissionCompleted callback) {
    RequestLocalNetworkPermissionCompletedDelegate = callback;
}

void Permissions_RequestLocalNetworkPermission(void) {
    [[Permissions sharedInstance] requestLocalNetworkPermission];
}

void Permissions_SetJumpToAppSettingsCompletedDelegate(JumpToAppSettingsCompleted callback) {
    JumpToAppSettingsCompletedDelegate = callback;
}

void Permissions_JumpToAppSettings(void) {
    [[Permissions sharedInstance] jumpToAppSettings];
}
