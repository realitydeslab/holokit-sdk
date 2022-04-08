//
//  watch_connectivity.m
//  watch_connectivity
//
//  Created by Yuchen on 2021/8/30.
//

#import "watch_connectivity.h"
#import "math_helpers.h"
#import "IUnityInterface.h"

typedef void (*DidReceiveWatchMessage)(int messageIndex);
DidReceiveWatchMessage DidReceiveWatchMessageDelegate = NULL;

typedef void (*DidReceiveWatchInput)(int inputIndex);
DidReceiveWatchInput DidReceiveWatchInputDelegate = NULL;

typedef void (*DidReceiveCalorieMessage)(float calories);
DidReceiveCalorieMessage DidReceiveCalorieMessageDelegate = NULL;

@interface WatchConnectivity() <WCSessionDelegate>

@property (nonatomic, strong) WCSession *wcSession;

@end

@implementation WatchConnectivity

- (instancetype)init {
    if (self = [super init]) {
        if ([WCSession isSupported]) {
            self.wcSession = [WCSession defaultSession];
            self.wcSession.delegate = self;
            // We let Unity manually activate the session when needed.
            [self.wcSession activateSession];
        }
    }
    return self;
}

- (void)sendMessage2WatchWithMessageType:(NSString *)messageType messageIndex:(int)index {
    if (self.wcSession.isReachable) {
        NSDictionary<NSString *, id> *message = @{ messageType : [NSNumber numberWithInt:index] };
        [self.wcSession sendMessage:message replyHandler:nil errorHandler:nil];
    } else {
        NSLog(@"[wc_session] Watch is currently not reachable.");
    }
}

+ (id)sharedWatchConnectivity {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - WCSessionDelegate

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error {
    if (activationState == WCSessionActivationStateActivated) {
        NSLog(@"[wc_session]: activation did compelete with state activated.");
    } else if (activationState == WCSessionActivationStateInactive) {
        NSLog(@"[wc_session]: activation did compelete with state inactive.");
    } else if (activationState == WCSessionActivationStateNotActivated) {
        NSLog(@"[wc_session]: activation did compelete with state not activated.");
    }
}

- (void)sessionReachabilityDidChange:(WCSession *)session {
    if (session.isReachable) {
        NSLog(@"[wc_session]: session reachability did change to reachable.");
    } else {
        NSLog(@"[wc_session]: session reachability did change to not reachable.");
    }
}

- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
    if (id playerInputValue = [message objectForKey:@"WatchInput"]) {
        NSInteger playerInput = [playerInputValue integerValue];
        if (DidReceiveWatchInputDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DidReceiveWatchInputDelegate((int)playerInput);
            });
        }
    } else if (id watchSystemValue = [message objectForKey:@"WatchMessage"]) {
        NSInteger watchSystemIndex = [watchSystemValue integerValue];
        if (DidReceiveWatchMessageDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DidReceiveWatchMessageDelegate((int)watchSystemIndex);
            });
        }
    } else if (id watchCalorieValue = [message objectForKey:@"Calorie"]) {
        float calories = [watchCalorieValue floatValue];
        if (DidReceiveCalorieMessageDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DidReceiveCalorieMessageDelegate(calories);
            });
        }
     }
}

- (void)sessionDidBecomeInactive:(nonnull WCSession *)session {
    
}


- (void)sessionDidDeactivate:(nonnull WCSession *)session {
    
}

@end

#pragma mark - extern "C"

extern "C" {

// You need to manually init WCSession in Unity.
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_InitWatchConnectivity() {
    [WatchConnectivity sharedWatchConnectivity];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SendMessage2Watch(const char *messageType, int index) {
    WatchConnectivity *wc_session = [WatchConnectivity sharedWatchConnectivity];
    [wc_session sendMessage2WatchWithMessageType:[NSString stringWithUTF8String:messageType] messageIndex:index];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveWatchMessageDelegate(DidReceiveWatchMessage callback) {
    DidReceiveWatchMessageDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveWatchInputDelegate(DidReceiveWatchInput callback) {
    DidReceiveWatchInputDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveCalorieMessageDelegate(DidReceiveCalorieMessage callback) {
    DidReceiveCalorieMessageDelegate = callback;
}

} // extern "C"
