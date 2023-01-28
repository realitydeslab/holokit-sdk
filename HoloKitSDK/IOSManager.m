#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void (*OnThermalStateChanged)(int) = NULL;

@interface IOSManager : NSObject

@end

@interface IOSManager()

@end

@implementation IOSManager

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OnThermalStateChanged) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
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

- (void)OnThermalStateChanged {
    if (OnThermalStateChanged != NULL) {
        NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
        dispatch_async(dispatch_get_main_queue(), ^{
            OnThermalStateChanged((int)thermalState);
        });
    }
}

@end

void HoloKitSDK_RegisterIOSNativeDelegates(void (*OnThermalStateChangedDelegate)(int)) {
    [IOSManager sharedInstance];
    OnThermalStateChanged = OnThermalStateChangedDelegate;
}

int HoloKitSDK_GetThermalState(void) {
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    return (int)thermalState;
}

double HoloKitSDK_GetSystemUptime(void) {
    return [[NSProcessInfo processInfo] systemUptime];
}

void HoloKitSDK_SetScreenBrightness(float brightness) {
    [[UIScreen mainScreen] setBrightness:brightness];
}

float HoloKitSDK_GetScreenBrightness(void) {
    return [[UIScreen mainScreen] brightness];
}
