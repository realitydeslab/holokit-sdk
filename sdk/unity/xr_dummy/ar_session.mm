//
//  arsession.m
//  holokit
//
//  Created by Botao Hu on 10/18/20.
//

#include "XR/UnityXRNativePtrs.h"
#include "unity/xr_dummy/printc.h"
#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>

@interface ARSessionDelegateController : NSObject <ARSessionDelegate>
{}
//- (instancetype)initWithARSessionDelegate:(ARSessionDelegate *)unityARSessionDelegate;
@end


@implementation ARSessionDelegateController
{}

+ (id) sharedARSessionDelegateController {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}
#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    NSLog(@"frame.timestamp: %f,  systemuptime: %f", frame.timestamp, [[NSProcessInfo processInfo] systemUptime]);
}
@end

void SetARSession(UnityXRNativeSession* ar_native_session) {
    printout("SetARSession is called");
    
    NSLog(@"ar_native_session=%d\n", reinterpret_cast<size_t>(ar_native_session));
    if (ar_native_session == nullptr) {
        NSLog(@"Native ARSession is NULL.");
        return;
    }
    
    ARSession* session = (__bridge ARSession*) ar_native_session->sessionPtr;
    NSLog(@"ar_native_session->sessionPtr=%d\n", reinterpret_cast<size_t>(ar_native_session->sessionPtr));

    NSLog(@"identifier=%@", session.identifier);
    ARFrame* frame = session.currentFrame;
    if (frame != nullptr) {
        NSLog(@"session.currentFrame.camera.intrinsics.columns[0]=%f", session.currentFrame.camera.intrinsics.columns[0]);
    }

    
    
//    NSObject *obj = session.delegate;
//    NSLog(@"%@", NSStringFromClass( [someObject class] );

//
    NSLog(@"before session.delegate=%d\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));
 
    [session setDelegate:ARSessionDelegateController.sharedARSessionDelegateController];

    NSLog(@"after session.delegate=%d\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));

//    NSLog(@"controller=%d\n", reinterpret_cast<size_t>((__bridge void *)(controller)));
//    session.delegate = controller;
}



#else

void SetARSession(UnityXRNativeSession* ar_native_session) {
    printout("SetARSession on mac");
}

#endif
