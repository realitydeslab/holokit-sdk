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
#import "LandmarkPosition.h"

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

static const float kMaxLandmarkDistance = 0.8f;

@interface ARSessionDelegateController : NSObject <ARSessionDelegate, TrackerDelegate>

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) NSOperationQueue* motionQueue;
@property (nonatomic, strong) HandTracker* handTracker;
//@property (nonatomic, strong) NSArray<NSArray<Landmark *> *> *landmarks;
@property (nonatomic, strong) NSMutableArray<LandmarkPosition *> *leftHandLandmarkPositions;
@property (nonatomic, strong) NSMutableArray<LandmarkPosition *> *rightHandLandmarkPositions;
@property (assign) float lastHandTrackingTimestamp;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;

@property (nonatomic, strong) ARFrame* frame;
@property (assign) simd_float4x4 cameraTransform;
@property (nonatomic, strong) ARSession* session;

@property (nonatomic, strong) CMMotionManager* motionManager;

@end

@implementation ARSessionDelegateController

- (instancetype)init {
    if(self = [super init]) {
        self.handTracker = [[HandTracker alloc] init];
        self.handTracker.delegate = self;
        [self.handTracker startGraph];
        
        self.handTrackingQueue = [[NSOperationQueue alloc] init];
        self.handTrackingQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionQueue = [[NSOperationQueue alloc] init];
        self.motionQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionManager = [[CMMotionManager alloc] init];
        
        self.leftHandLandmarkPositions = [[NSMutableArray alloc] init];
        self.rightHandLandmarkPositions = [[NSMutableArray alloc] init];
        for(int i = 0; i < 21; i++){
            LandmarkPosition *position = [[LandmarkPosition alloc] initWithX:0.0 y:0.0 z:0.0];
            [self.leftHandLandmarkPositions addObject:position];
            [self.rightHandLandmarkPositions addObject:position];
        }
        NSLog(@"array capacities: %lu and %d", [self.leftHandLandmarkPositions count], [self.rightHandLandmarkPositions count]);
        
        self.isLeftHandTracked = true;
        self.isRightHandTracked = true;
        self.lastHandTrackingTimestamp = [[NSProcessInfo processInfo] systemUptime];
        
        
        //[self startAccelerometer];
        //[self startGyroscope];
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
    //NSLog(@"[Frame] thread=%@, frame.timestamp=%f,  systemuptime=%f", [NSThread currentThread], frame.timestamp, [[NSProcessInfo processInfo] systemUptime]);
    //OSType type = CVPixelBufferGetPixelFormatType(frame.capturedImage);
    //OSType type2 = CVPixelBufferGetPixelFormatType(frame.smoothedSceneDepth.depthMap);
    //NSLog(@"type %d", type);
    //NSLog(@"type depth %d", type2);

    
    self.frame = session.currentFrame;
    self.cameraTransform = session.currentFrame.camera.transform;
    if(self.session == NULL) {
        NSLog(@"initialize ARSession reference.");
        self.session = session;
    }
    
    float currentTimestamp = [[NSProcessInfo processInfo] systemUptime];
    if((currentTimestamp - self.lastHandTrackingTimestamp) > 1.0f) {
        NSLog(@"No hand found");
        self.isLeftHandTracked = false;
        self.isRightHandTracked = false;
    }
    
    //NSLog(@"trying to run mediapipe...");
    [self.handTrackingQueue addOperationWithBlock:^{
        [self.handTracker processVideoFrame: frame.capturedImage];
    }];
}

#pragma mark - HandTracking

- (simd_float3)unprojectScreenPoint:(CGPoint)screenPoint depth:(float)z currentFrame:(ARFrame *) frame {
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    //simd_float4x4 planeOrigin = simd_mul(frame.camera.transform, translation);
    simd_float4x4 planeOrigin = simd_mul(self.session.currentFrame.camera.transform, translation);
    //NSLog(@"frame camera transform------------------------------------");
    //[self logMatrix4x4:frame.camera.transform];
    //NSLog(@"session camera transform------------------------------------");
    //[self logMatrix4x4:self.session.currentFrame.camera.transform];
    //NSLog(@"camera coordinate [%f, %f, %f]", self.cameraTransform.columns[3].x, self.cameraTransform.columns[3].y, self.cameraTransform.columns[3].z);
    simd_float3 xAxis = simd_make_float3(1, 0, 0);
    simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
    simd_float4x4 plane = simd_mul(planeOrigin, rotation);
    simd_float3 unprojectedPoint = [self.session.currentFrame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:self.session.currentFrame.camera.imageResolution];
    
    return unprojectedPoint;
}

- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    self.lastHandTrackingTimestamp = [[NSProcessInfo processInfo] systemUptime];
    self.isLeftHandTracked = true;
    if([multiLandmarks count] > 1) {
        self.isRightHandTracked = true;
    } else{
        self.isRightHandTracked = false;
    }
    
    //NSLog(@"handTracker()");
    int handIndex = 0;
    for(NSArray<Landmark *> *landmarks in multiLandmarks) {
        int landmarkIndex = 0;
        for(Landmark *landmark in landmarks) {
        
            int x = (CGFloat)landmark.x * self.frame.camera.imageResolution.width;
            int y = (CGFloat)landmark.y * self.frame.camera.imageResolution.height;
            CGPoint screenPoint = CGPointMake(x, y);
            
            //NSLog(@"landmark [%f, %f]", landmark.x, landmark.y);
            size_t depthBufferWidth;
            size_t depthBufferHeight;
            Float32* depthBufferBaseAddress;
            ARDepthData* sceneDepth = self.frame.sceneDepth;
            if(!sceneDepth) {
                NSLog(@"ViewController");
                NSLog(@"Failed to acquire scene depth.");
                return;
            } else {
                //NSLog(@"Scene depth was acquired successfully!");
                CVPixelBufferRef depthPixelBuffer = sceneDepth.depthMap;
                CVPixelBufferLockBaseAddress(depthPixelBuffer, 0);
                depthBufferWidth = CVPixelBufferGetWidth(depthPixelBuffer);
                depthBufferHeight = CVPixelBufferGetHeight(depthPixelBuffer);
                depthBufferBaseAddress = (Float32*)CVPixelBufferGetBaseAddress(depthPixelBuffer);
            }
            
            // fetch the depth value of this landmark
            int bufferX = CLAMP(landmark.x, 0, 1) * depthBufferWidth;
            int bufferY = CLAMP(landmark.y, 0, 1) * depthBufferHeight;
            float landmarkDepth = depthBufferBaseAddress[bufferY * depthBufferWidth + bufferX];
            //float landmarkDepth = 0.5;
            
            // eliminate landmark which is too distant to the user, which is obviously wrong data
            
            
            simd_float3 unprojectedPoint = [self unprojectScreenPoint:screenPoint depth:landmarkDepth currentFrame:self.frame];
            
            //NSLog(@"raw landmark coordinate: [%f, %f]", landmark.x, landmark.y);
            //NSLog(@"point in world: [%f, %f, %f]", unprojectedPoint.x, unprojectedPoint.y, unprojectedPoint.z);
            LandmarkPosition *position = [[LandmarkPosition alloc] initWithX:unprojectedPoint.x y:unprojectedPoint.y z:unprojectedPoint.z];
            //NSLog(@"position: [%f, %f, %f]", position.x, position.y, position.z);
            if (handIndex == 0) {
                [self.leftHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            } else if (handIndex == 1) {
                [self.rightHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            }
            landmarkIndex++;
        }
        //NSLog(@"landmark position: [%f, %f]", self.rightHandLandmarkPositions[0].x, self.rightHandLandmarkPositions[0].y);
        handIndex++;
    }
    
    //NSLog(@"Left %d, Right %d", self.isLeftHandTracked, self.isRightHandTracked);
}

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses { }

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer { }

// print out the matrix column by column
- (void)logMatrix4x4:(simd_float4x4)mat {
    //NSLog(@"simd_float4x4;");
    NSLog(@"[%f %f %f %f]", mat.columns[0].x, mat.columns[0].y, mat.columns[0].z, mat.columns[0].w);
    NSLog(@"[%f %f %f %f]", mat.columns[1].x, mat.columns[1].y, mat.columns[1].z, mat.columns[1].w);
    NSLog(@"[%f %f %f %f]", mat.columns[2].x, mat.columns[2].y, mat.columns[2].z, mat.columns[2].w);
    NSLog(@"[%f %f %f %f]", mat.columns[3].x, mat.columns[3].y, mat.columns[3].z, mat.columns[3].w);
}

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
    //session.delegate = ARSessionDelegateController.sharedARSessionDelegateController;
    
    //ARWorldTrackingConfiguration *newConfiguration = [ARWorldTrackingConfiguration new];
    //newConfiguration.frameSemantics = ARFrameSemanticSceneDepth;
    //NSLog(@"before runWithConfig");
    //[session runWithConfiguration:newConfiguration];
    //NSLog(@"after runWithConfig");
    
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
    SetARSession(ar_native_session);
}
