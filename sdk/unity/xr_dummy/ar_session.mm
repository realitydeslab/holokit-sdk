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
#import <CoreVideo/CoreVideo.h>
#import <HandTracker/HandTracker.h>

@interface ARSessionDelegateController : NSObject <ARSessionDelegate, TrackerDelegate>
{}
@property (weak, nonatomic) HandTracker* _handTracker;

//- (instancetype)initWithARSessionDelegate:(ARSessionDelegate *)unityARSessionDelegate;
@end


@implementation ARSessionDelegateController
{}


- (instancetype) init {
    handTracker = [[HandTracker alloc] init];
    handTracker.delegate = self;
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

- (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<Landmark *> *)landmarks {
    
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer {
        
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    NSLog(@"frame.timestamp: %f,  systemuptime: %f", frame.timestamp, [[NSProcessInfo processInfo] systemUptime]);
    OSType type = CVPixelBufferGetPixelFormatType(frame.capturedImage);
    OSType type2 = CVPixelBufferGetPixelFormatType(frame.smoothedSceneDepth.depthMap);
    NSLog(@"type %d", type);
    NSLog(@"type depth %d", type2);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [handTracker processVideoFrame: frame.capturedImage];
    });

    
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
