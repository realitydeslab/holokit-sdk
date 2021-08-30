//
//  watch_connectivity.m
//  watch_connectivity
//
//  Created by Yuchen on 2021/8/30.
//

#import <Foundation/Foundation.h>
#import "watch_connectivity.h"

typedef void (*DidReceiveWatchActionMessage)(int messageIndex, double watchYaw, double iphoneYaw);
DidReceiveWatchActionMessage DidReceiveWatchActionMessageDelegate = NULL;

@interface HoloKitWatchConnectivity() <WCSessionDelegate>

@property (nonatomic, strong) WCSession *wcSession;

@end

@implementation HoloKitWatchConnectivity

- (instancetype)init {
    if (self = [super init]) {
        if ([WCSession isSupported]) {
            self.wcSession = [WCSession defaultSession];
            self.wcSession.delegate = self;
            // We let Unity manually activate the session when needed.
            //[self.wcSession activateSession];
        }
    }
    return self;
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
    if (id watchActionValue = [message objectForKey:@"WatchAction"]) {
        if (id watchYawValue = [message objectForKey:@"WatchYaw"]) {
            NSInteger watchActionIndex = [watchActionValue integerValue];
            NSInteger watchYaw = [watchYawValue integerValue];
            //DidReceiveWatchActionMessageDelegate(watchActionIndex, watchYaw, )
        }
        
    }

}

- (void)sessionDidBecomeInactive:(nonnull WCSession *)session {
    
}


- (void)sessionDidDeactivate:(nonnull WCSession *)session {
    
}


@end
