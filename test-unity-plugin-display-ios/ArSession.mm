//
//  ArSession.m
//  test-unity-plugin-display-ios
//
//  Created by Yuchen on 2021/3/28.
//

#include "XR/UnityXRNativePtrs.h"
#include <TargetConditionals.h>
#include "UnityXRTypes.h"
#include "IUnityInterface.h"
#include "XR/UnitySubsystemTypes.h"

#if TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>

@interface ARSessionDelegateController : NSObject <ARSessionDelegate>
{}
@property (nonatomic, strong) ARSession* session;
@property (nonatomic, strong) ARFrame* frame;
@property (nonatomic, strong) ARCamera* camera;
//- (instancetype)initWithARSessionDelegate:(ARSessionDelegate *)unityARSessionDelegate;
@end


@implementation ARSessionDelegateController
{}


- (instancetype) init {
    if(self = [super init]) {
        
    }
    return self;
}

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
    OSType type = CVPixelBufferGetPixelFormatType(frame.capturedImage);
    OSType type2 = CVPixelBufferGetPixelFormatType(frame.smoothedSceneDepth.depthMap);
    NSLog(@"type %d", type);
    NSLog(@"type depth %d", type2);
    
    // only set once
    if(self.session == NULL) {
        self.session = session;
        self.frame = session.currentFrame;
        self.camera = session.currentFrame.camera;
    }
    
    
//
//    switch (format) {
//        case kCVPixelFormatType_32BGRA:
//          return GpuBufferFormat::kBGRA32;
//        case kCVPixelFormatType_DepthFloat32:
//          return GpuBufferFormat::kGrayFloat32;
//        case kCVPixelFormatType_OneComponent16Half:
//          return GpuBufferFormat::kGrayHalf16;
//        case kCVPixelFormatType_OneComponent32Float:
//          return GpuBufferFormat::kGrayFloat32;
//        case kCVPixelFormatType_OneComponent8:
//          return GpuBufferFormat::kOneComponent8;
//        case kCVPixelFormatType_TwoComponent16Half:
//          return GpuBufferFormat::kTwoComponentHalf16;
//        case kCVPixelFormatType_TwoComponent32Float:
//          return GpuBufferFormat::kTwoComponentFloat32;
//        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
//          return GpuBufferFormat::kBiPlanar420YpCbCr8VideoRange;
//        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
//          return GpuBufferFormat::kBiPlanar420YpCbCr8FullRange;
//        case kCVPixelFormatType_24RGB:
//          return GpuBufferFormat::kRGB24;
//        case kCVPixelFormatType_64RGBAHalf:
//          return GpuBufferFormat::kRGBAHalf64;
//        case kCVPixelFormatType_128RGBAFloat:
//          return GpuBufferFormat::kRGBAFloat128;
//      }
    
}
@end

void SetARSession(UnityXRNativeSession* ar_native_session) {
    
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

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    NSLog(@"SetARSession is called in the SDK hahaha");
    SetARSession(ar_native_session);
}
