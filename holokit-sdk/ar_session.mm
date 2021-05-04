//
//  hand_tracking.m
//  test-unity-input-ios
//
//  Created by Yuchen on 2021/3/6.
//
#pragma once

#include "ar_session.h"
#include "UnityXRNativePtrs.h"
#include <TargetConditionals.h>
#include "UnityXRTypes.h"
#include "IUnityInterface.h"
#include "XR/UnitySubsystemTypes.h"
#include "math_helpers.h"
#import "hand_tracking.h"
#import <vector>
#import "LandmarkPosition.h"
#import "ARcore.h"

//#if TARGET_OS_IPHONE
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

std::unique_ptr<AR::ARCore> AR_estimator;

@interface ARSessionDelegateController ()

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) NSOperationQueue* motionQueue;
@property (nonatomic, strong) HandTracker* handTracker;
@property (assign) double lastHandTrackingTimestamp;

@property (nonatomic, strong) CMMotionManager* motionManager;

@property (nonatomic, strong) MultipeerSession *multipeerSession;

@end

@implementation ARSessionDelegateController

#pragma mark - init
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
        
        // MODIFY HERE
        self.isHandTrackingEnabled = YES;
        
        // Set up multipeer session
        void (^receivedDataHandler)(NSData *, MCPeerID *) = ^void(NSData *data, MCPeerID *peerID) {
            //NSLog(@"receivedDataHandler");
            ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
            if (collaborationData != NULL) {
                [self.session updateWithCollaborationData:collaborationData];
                return;
            }
            NSLog(@"Failed to receive data.");
        };
        self.multipeerSession = [[MultipeerSession alloc] initWithReceivedDataHandler:receivedDataHandler];
        
        AR_estimator.reset(new AR::ARCore());
        AR_estimator->start(30);

        [self startAccelerometer];
        [self startGyroscope];
    }
    return self;
}


- (void)startAccelerometer {
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        self.motionManager.accelerometerUpdateInterval = 1.0 / 100.0;
        [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            //NSLog(@"[Accel] thread=%@, accelerometerData.timestamp=%f, systemuptime=%f, accelerometerData.acceleration.x=%f, accelerometerData.acceleration.y=%f, accelerometerData.acceleration.z=%f", [NSThread currentThread], accelerometerData.timestamp, [[NSProcessInfo processInfo] systemUptime], accelerometerData.acceleration.x, accelerometerData.acceleration.y, accelerometerData.acceleration.z);
            AR::ImuAccData cur_acc;
            cur_acc.delivery_timestamp = [[NSProcessInfo processInfo] systemUptime];
            cur_acc.event_timestamp = accelerometerData.timestamp;
            cur_acc.ax = accelerometerData.acceleration.x;
            cur_acc.ay = accelerometerData.acceleration.y;
            cur_acc.az = accelerometerData.acceleration.z;
            AR_estimator->addAccMeasurement(cur_acc);
        }];
    }
}

- (void)startGyroscope {
    if ([self.motionManager isGyroAvailable] == YES) {
        self.motionManager.gyroUpdateInterval = 1.0 / 100.0;
        [self.motionManager startGyroUpdatesToQueue:self.motionQueue withHandler:^(CMGyroData *gyroData, NSError *error) {
            
            AR::ImuGyrData cur_gyr;
            cur_gyr.delivery_timestamp = [[NSProcessInfo processInfo] systemUptime];
            cur_gyr.event_timestamp = gyroData.timestamp;
            cur_gyr.wx = gyroData.rotationRate.x;
            cur_gyr.wy = gyroData.rotationRate.y;
            cur_gyr.wz = gyroData.rotationRate.z;
            AR_estimator->addGyrMeasurement(cur_gyr);

           
           // NSLog(@"[Gyro] thread=%@, gyroData.timestamp=%f, systemuptime=%f, gyroData.rotationRate.x=%f, gyroData.rotationRate.y=%f, gyroData.rotationRate.z=%f", [NSThread currentThread], gyroData.timestamp, [[NSProcessInfo processInfo] systemUptime], gyroData.rotationRate.x, gyroData.rotationRate.y,
           //       gyroData.rotationRate.z);
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
    
    //LogMatrix4x4(frame.camera.transform);
    //frame.camera.intrinsics
    
    simd_float4x4 trans = frame.camera.transform;
    simd_quatf quat = /*simd_normalize*/(simd_quaternion(trans));
    
    AR::ARkitData cur_ARkit;
    cur_ARkit.delivery_timestamp = [[NSProcessInfo processInfo] systemUptime];
    cur_ARkit.event_timestamp = frame.timestamp;
    cur_ARkit.ARkit_Position = AR::ARVector3d{trans.columns[3][0], trans.columns[3][1], trans.columns[3][2]};
    cur_ARkit.ARkit_Rotation = AR::ARQuaterniond{quat.vector[3], quat.vector[0], quat.vector[1], quat.vector[2]};

    AR_estimator->addARKitMeasurement(cur_ARkit);
    
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    if(self.session == NULL) {
        NSLog(@"[ar_session]: got session reference.");
        self.session = session;
    }
    
    float currentTimestamp = [[NSProcessInfo processInfo] systemUptime];
    if((currentTimestamp - self.lastHandTrackingTimestamp) > 1.0f) {
        //NSLog(@"No hand found");
        self.isLeftHandTracked = false;
        self.isRightHandTracked = false;
    }
    
    // Hand tracking
    if (self.isHandTrackingEnabled) {
        [self.handTrackingQueue addOperationWithBlock:^{
            [self.handTracker processVideoFrame: frame.capturedImage];
        }];
    }
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
    }
    NSLog(@"[ar_session]: did add anchor.");
    for (ARAnchor *anchor in anchors) {
        // Check if this anchor is a new peer
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            NSLog(@"A new peer is connected into the collaboration session.");
            [self.session addAnchor:anchor];
        }
    }
}
- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateAnchors:anchors];
    }
    NSLog(@"[ar_session]: did update anchor.");
}

- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didRemoveAnchors:anchors];
    }
}

- (void)session:(ARSession *)session didOutputCollaborationData:(ARCollaborationData *)data {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    if (self.multipeerSession == nil) {
        return;
    }
    if ([self.multipeerSession GetConnectedPeers].count == 0) {
        //NSLog(@"Deferred sending collaboration to later because there are no peers.");
        return;
    }
    // If there is at least one peer nearby, send the newly updated collaboration data
    // to all peers.
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:nil];
    [self.multipeerSession sendToAllPeers:encodedData];
}


#pragma mark - HandTracking

- (simd_float3)unprojectScreenPoint:(CGPoint)screenPoint depth:(float)z {
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    simd_float4x4 planeOrigin = simd_mul(self.session.currentFrame.camera.transform, translation);
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
    
    int handIndex = 0;
    for(NSArray<Landmark *> *landmarks in multiLandmarks) {
        int landmarkIndex = 0;
        float totalLandmarkDepth = 0;
        for(Landmark *landmark in landmarks) {
        
            int x = (CGFloat)landmark.x * self.session.currentFrame.camera.imageResolution.width;
            int y = (CGFloat)landmark.y * self.session.currentFrame.camera.imageResolution.height;
            CGPoint screenPoint = CGPointMake(x, y);
            
            //NSLog(@"landmark [%f, %f]", landmark.x, landmark.y);
            size_t depthBufferWidth;
            size_t depthBufferHeight;
            Float32* depthBufferBaseAddress;
            ARDepthData* sceneDepth = self.session.currentFrame.sceneDepth;
            if(!sceneDepth) {
                NSLog(@"[AR Session]: Failed to acquire scene depth.");
                return;
            } else {
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
            totalLandmarkDepth += landmarkDepth;

            simd_float3 unprojectedPoint = [self unprojectScreenPoint:screenPoint depth:landmarkDepth];
            LandmarkPosition *position = [[LandmarkPosition alloc] initWithX:unprojectedPoint.x y:unprojectedPoint.y z:unprojectedPoint.z];
            if (handIndex == 0) {
                [self.leftHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            } else if (handIndex == 1) {
                [self.rightHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            }
            landmarkIndex++;
        }
        // If the average depth is too far away?
        if((totalLandmarkDepth / 21) > kMaxLandmarkDistance) {
            //NSLog(@"[ar_session]: wrong hand data detected.");
            if(handIndex == 0){
                self.isLeftHandTracked = false;
                self.isRightHandTracked = false;
                return;
            } else if(handIndex == 1) {
                self.isRightHandTracked = false;
                return;
            }
        }
        handIndex++;
    }
}
    

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses {
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer { }

- (float)euclideanDistance:(simd_float2)point1 point2:(simd_float2)point2 {
    return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2));
}

@end

#pragma mark - SetARSession
void SetARSession(UnityXRNativeSession* ar_native_session) {
    
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

    NSLog(@"before session.delegate=%zu\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));

    ARSessionDelegateController* ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
    ar_session_handler.unityARSessionDelegate = session.delegate;
    
    [session setDelegate:ARSessionDelegateController.sharedARSessionDelegateController];
    
    NSLog(@"after session.delegate=%zu\n", reinterpret_cast<size_t>((__bridge void *)(session.delegate)));

//    NSLog(@"controller=%d\n", reinterpret_cast<size_t>((__bridge void *)(controller)));
//    session.delegate = controller;
}



//#else
//void SetARSession(UnityXRNativeSession* ar_native_session) {
//    printout("SetARSession on mac");
//}
//#endif

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    SetARSession(ar_native_session);
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_EnableHandTracking(bool enabled) {
    ARSessionDelegateController* ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
    ar_session_handler.isHandTrackingEnabled = enabled;
    NSLog(@"[ar_session]: EnableHandTracking(%d)", enabled);
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = matrix_identity_float4x4;
    NSLog(@"[ar_session]: set world origin.");
    float converted_rotation[4];
    // The structure of converted_rotation is { w, x, y, z }
    converted_rotation[0] = rotation[3];
    converted_rotation[1] = -rotation[0];
    converted_rotation[2] = -rotation[1];
    converted_rotation[3] = rotation[2];
    // Convert quaternion to rotation matrix
    // See: https://automaticaddison.com/how-to-convert-a-quaternion-to-a-rotation-matrix/
    transform_matrix.columns[0].x = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[1] * converted_rotation[1]) - 1;
    transform_matrix.columns[0].y = 2 * (converted_rotation[1] * converted_rotation[2] + converted_rotation[0] * converted_rotation[3]);
    transform_matrix.columns[0].z = 2 * (converted_rotation[1] * converted_rotation[3] - converted_rotation[0] * converted_rotation[2]);
    transform_matrix.columns[1].x = 2 * (converted_rotation[1] * converted_rotation[2] - converted_rotation[0] * converted_rotation[3]);
    transform_matrix.columns[1].y = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[2] * converted_rotation[2]) - 1;
    transform_matrix.columns[1].z = 2 * (converted_rotation[2] * converted_rotation[3] + converted_rotation[0] * converted_rotation[1]);
    transform_matrix.columns[2].x = 2 * (converted_rotation[1] * converted_rotation[3] + converted_rotation[0] * converted_rotation[2]);
    transform_matrix.columns[2].y = 2 * (converted_rotation[2] * converted_rotation[3] - converted_rotation[0] * converted_rotation[1]);
    transform_matrix.columns[2].z = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[3] * converted_rotation[3]) - 1;
    // Convert translate into matrix
    transform_matrix.columns[3].x = position[0];
    transform_matrix.columns[3].y = position[1];
    transform_matrix.columns[3].z = -position[2];
    
    ARSessionDelegateController* ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
    [ar_session_handler.session setWorldOrigin:(transform_matrix)];
}

