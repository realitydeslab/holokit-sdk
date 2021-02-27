//
//  hand_tracking.m
//  test-unity-input-ios
//
//  Created by Yuchen on 2021/3/6.
//

#include "UnityXRNativePtrs.h"
#include "unity/xr_dummy/printc.h"
#include <TargetConditionals.h>
#include "UnityXRTypes.h"
#include "IUnityInterface.h"
#include "XR/UnitySubsystemTypes.h"

#import "hand_tracking.h"
#import <vector>

#if TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#import <HandTracker/HandTracker.h>
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMotion/CoreMotion.h>

#define MIN(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#define MAX(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })

#define CLAMP(x, low, high) ({\
  __typeof__(x) __x = (x); \
  __typeof__(low) __low = (low);\
  __typeof__(high) __high = (high);\
  __x > __high ? __high : (__x < __low ? __low : __x);\
  })

@interface ARSessionDelegateController : NSObject <ARSessionDelegate, TrackerDelegate>

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) NSOperationQueue* motionQueue;
@property (nonatomic, strong) HandTracker* handTracker;
//@property (nonatomic, strong) NSArray<NSArray<Landmark *> *> *landmarks;
@property std::vector<std::vector<UnityXRVector3>> landmarkPositions;

@property (nonatomic, strong) ARFrame* frame;
@property (assign) CGFloat cameraImageResolutionWidth;
@property (assign) CGFloat cameraImageResolutionHeight;
@property (assign) Float32* depthBufferBaseAddress;
@property (assign) size_t depthBufferWidth;
@property (assign) size_t depthBufferHeight;

@property (nonatomic, strong) CMMotionManager* motionManager;

@end

@implementation ARSessionDelegateController

- (instancetype)init {
    if(self = [super init]) {
        self.handTracker = [[HandTracker alloc] init];
        self.handTracker.delegate = self;
        NSLog(@"<<<<<<<<<<<777777777777777");
        [self.handTracker startGraph];
        
        self.handTrackingQueue = [[NSOperationQueue alloc] init];
        self.handTrackingQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionQueue = [[NSOperationQueue alloc] init];
        self.motionQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionManager = [[CMMotionManager alloc] init];
        
        self.landmarkPositions = std::vector<std::vector<UnityXRVector3>>(2);
        NSLog(@"<<<<<<<<<<resized ll = %ud", self.landmarkPositions.size());
        (self.landmarkPositions)[0].resize(21); // = std::vector<UnityXRVector3>(21, UnityXRVector3 {.x = 0, .y=0, .z=0});
        NSLog(@"<<<<<<<<<<resized 0 = %ud", (self.landmarkPositions)[0].size());
        (self.landmarkPositions)[1].resize(21); // = std::vector<UnityXRVector3>(21, UnityXRVector3 {.x = 0, .y=0, .z=0});
        NSLog(@"<<<<<<<<<<resized 1 = %ud", (self.landmarkPositions)[1].size());
        
        
        printf("<<<<<<<<<<resized %f", self.landmarkPositions[0][0].x);

        NSLog(@"<<<<<<<<<<resized");

        [self startAccelerometer];
        [self startGyroscope];
    }
    return self;
}



- (void)startAccelerometer {
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        self.motionManager.accelerometerUpdateInterval = 1.0 / 100.0;
        [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
          //  NSLog(@"[Accel] thread=%@, accelerometerData.timestamp=%f, systemuptime=%f, accelerometerData.acceleration.x=%f, accelerometerData.acceleration.y=%f, accelerometerData.acceleration.z=%f", [NSThread currentThread], accelerometerData.timestamp, [[NSProcessInfo processInfo] systemUptime], accelerometerData.acceleration.x, accelerometerData.acceleration.y,
           //       accelerometerData.acceleration.z);
        }];
    }
}

- (void)startGyroscope {
    if ([self.motionManager isGyroAvailable] == YES) {
        self.motionManager.gyroUpdateInterval = 1.0 / 100.0;
        [self.motionManager startGyroUpdatesToQueue:self.motionQueue withHandler:^(CMGyroData *gyroData, NSError *error) {
           // self.gy_x = gyroData.rotationRate.x;
           // self.gy_y = gyroData.rotationRate.y;
           // self.gy_z = gyroData.rotationRate.z;
        //    NSLog(@"[Gyro] thread=%@, gyroData.timestamp=%f, systemuptime=%f, gyroData.rotationRate.x=%f, gyroData.rotationRate.y=%f, gyroData.rotationRate.z=%f", [NSThread currentThread], gyroData.timestamp, [[NSProcessInfo processInfo] systemUptime], gyroData.rotationRate.x, gyroData.rotationRate.y,
          //        gyroData.rotationRate.z);
        }];
    }
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
    NSLog(@"[Frame] thread=%@, frame.timestamp=%f,  systemuptime=%f", [NSThread currentThread], frame.timestamp, [[NSProcessInfo processInfo] systemUptime]);
    OSType type = CVPixelBufferGetPixelFormatType(frame.capturedImage);
    OSType type2 = CVPixelBufferGetPixelFormatType(frame.smoothedSceneDepth.depthMap);
    NSLog(@"type %d", type);
    NSLog(@"type depth %d", type2);

    // acquire scene depth
    //session.configuration.frameSemantics = ARFrameSemanticSceneDepth;
    //ARDepthData* sceneDepth = frame.sceneDepth;
    //if(!sceneDepth) {
    //    NSLog(@"ViewController");
    //    NSLog(@"Failed to acquire scene depth.");
    //} else {
    //    CVPixelBufferRef depthPixelBuffer = sceneDepth.depthMap;
    //    CVPixelBufferLockBaseAddress(depthPixelBuffer, 0);
    //    self.depthBufferWidth = CVPixelBufferGetWidth(depthPixelBuffer);
    //    self.depthBufferHeight = CVPixelBufferGetHeight(depthPixelBuffer);
    //    self.depthBufferBaseAddress = (Float32*)CVPixelBufferGetBaseAddress(depthPixelBuffer);
    //}
    
    self.cameraImageResolutionWidth = frame.camera.imageResolution.width;
    self.cameraImageResolutionHeight = frame.camera.imageResolution.height;
    
    self.frame = frame;
    
    [self.handTrackingQueue addOperationWithBlock:^{
        [self.handTracker processVideoFrame: frame.capturedImage];
    }];
}

#pragma mark - HandTracking

- (simd_float3)unprojectScreenPoint:(CGPoint)screenPoint depth:(float)z currentFrame:(ARFrame *) frame{
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    simd_float4x4 planeOrigin = simd_mul(frame.camera.transform, translation);
    simd_float3 xAxis = simd_make_float3(1, 0, 0);
    simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
    simd_float4x4 plane = simd_mul(planeOrigin, rotation);
    simd_float3 unprojectedPoint = [frame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:frame.camera.imageResolution];
    
    return unprojectedPoint;
}

- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    int handIndex = 0;
    int landmarkIndex = 0;
    for(NSArray<Landmark *> *landmarks in multiLandmarks) {
        for(Landmark *landmark in landmarks) {
            int x = (CGFloat)landmark.x * self.cameraImageResolutionWidth;
            int y = (CGFloat)landmark.y * self.cameraImageResolutionHeight;
            CGPoint screenPoint = CGPointMake(x, y);
            
            // fetch the depth value of this landmark
            int bufferX = CLAMP(landmark.x, 0, 1) * self.depthBufferWidth;
            int bufferY = CLAMP(landmark.y, 0, 1) * self.depthBufferHeight;
            //float landmarkDepth = self.depthBufferBaseAddress[bufferY * self.depthBufferWidth + bufferX];
            float landmarkDepth = 0.5;
            
            simd_float3 unprojectedPoint = [self unprojectScreenPoint:screenPoint depth:landmarkDepth currentFrame:self.frame];
            
            self.landmarkPositions[handIndex][landmarkIndex] = UnityXRVector3 { unprojectedPoint.x, unprojectedPoint.y, unprojectedPoint.z };
            landmarkIndex++;
        }
        handIndex++;
    }
    
}

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses { }

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer { }

@end

void SetARSession(UnityXRNativeSession* ar_native_session) {
    printout("SetARSession is called");
    
    NSLog(@"ar_native_session=%zu\n", reinterpret_cast<size_t>(ar_native_session));
    if (ar_native_session == nullptr) {
        NSLog(@"Native ARSession is NULL.");
        return;
    }
    
    ARSession* session = (__bridge ARSession*) ar_native_session->sessionPtr;
    NSLog(@"ar_native_session->version=%d, ar_native_session->sessionPtr=%zu\n",
          ar_native_session->version,
          reinterpret_cast<size_t>(ar_native_session->sessionPtr));

    NSLog(@"identifier=%@", session.identifier);
    ARFrame* frame = session.currentFrame;
    if (frame != nullptr) {
        NSLog(@"session.currentFrame.camera.intrinsics.columns[0]=%f", session.currentFrame.camera.intrinsics.columns[0]);
    }

    
//    NSObject *obj = session.delegate;
//    NSLog(@"%@", NSStringFromClass( [someObject class] );

//
    NSLog(@"before session.delegate=%zu\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));
 
    [session setDelegate:ARSessionDelegateController.sharedARSessionDelegateController];

    NSLog(@"after session.delegate=%zu\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));

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
    NSLog(@"<<<<<<<<<<<<<<888888888888");
    SetARSession(ar_native_session);
}
