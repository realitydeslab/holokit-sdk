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

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

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
    double startTime = [[NSProcessInfo processInfo] systemUptime];
    [permission requestPermissionWithCompletion:^(BOOL granted) {
        NSLog(@"[permissions] request local network permission completed with %d in %f", granted, [[NSProcessInfo processInfo] systemUptime] - startTime);

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

- (void)showAlertWithTitle:(NSString *)alertTitle message:(NSString *)alertMessage actionTitle:(NSString *)alertActionTitle  {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:alertActionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    }];
    
    [alert addAction:defaultAction];
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)openDeepLink:(NSString *)appUrl safariUrl:(NSString *)safariUrl {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appUrl] options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            NSLog(@"[deep_link] failed to open app url %@", appUrl);
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:safariUrl] options:@{} completionHandler:^(BOOL success) {
            }];
        }
    }];
}

- (void)mailTo:(NSString *)address {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", @"mailto:", address]] options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            NSLog(@"[mailto] failed to send mail to %@", address);
        }
    }];
}

- (void)openSafariLink:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            NSLog(@"[safari_link] failed to open url %@", url);
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

void Permissions_ShowAlert(const char *alertTitle, const char *alertMessage, const char *alertActionTitle) {
    if (alertMessage == nil) {
        [[Permissions sharedInstance] showAlertWithTitle:[NSString stringWithUTF8String:alertTitle] message:nil actionTitle:[NSString stringWithUTF8String:alertActionTitle]];
    } else {
        [[Permissions sharedInstance] showAlertWithTitle:[NSString stringWithUTF8String:alertTitle] message:[NSString stringWithUTF8String:alertMessage] actionTitle:[NSString stringWithUTF8String:alertActionTitle]];
    }
}

void Link_OpenDeepLink(const char *appUrl, const char *safariUrl) {
    if (appUrl != NULL && safariUrl != NULL) {
        [[Permissions sharedInstance] openDeepLink:[NSString stringWithUTF8String:appUrl] safariUrl:[NSString stringWithUTF8String:safariUrl]];
    }
}

void Link_MailTo(const char *address) {
    if (address != NULL) {
        [[Permissions sharedInstance] mailTo:[NSString stringWithUTF8String:address]];
    }
}

void Link_OpenSafariLink(const char *url) {
    if (url != NULL) {
        [[Permissions sharedInstance] openSafariLink:[NSString stringWithUTF8String:url]];
    }
}
