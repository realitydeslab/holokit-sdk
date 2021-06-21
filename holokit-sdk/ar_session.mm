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

#import <os/log.h>
#import <os/signpost.h>

#import "hand_tracking.h"
#import <vector>
#import "LandmarkPosition.h"

//#if TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#import <HandTracker/HandTracker.h>
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMotion/CoreMotion.h>
#import "profiling_data.h"

#define MIN(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#define MAX(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })

#define CLAMP(x, low, high) ({\
  __typeof__(x) __x = (x); \
  __typeof__(low) __low = (low);\
  __typeof__(high) __high = (high);\
  __x > __high ? __high : (__x < __low ? __low : __x);\
  })

static const float kMaxLandmarkDepth = 0.6f;

static const float kMaxLandmarkStartInterval = 0.12f;
static const float kMaxLandmark1Interval = 0.05f;
static const float kMaxLandmark2Interval = 0.03f;
static const float kMaxLandmarkEndInterval = 0.024f;

static const float kLostHandTrackingInterval = 0.5f;

typedef void (*AnchorCallbackFunction)(int val, float position_x, float position_y, float position_z,
                                       float rotation_x, float rotation_y, float rotation_z, float rotation_w);
AnchorCallbackFunction AnchorRevoke = NULL;

typedef void (*UpdatePeerHandPosition)(float x, float y, float z);
UpdatePeerHandPosition UpdatePeerHandPositionDelegate = NULL;

typedef void (*CollaborationSynchronized)();
CollaborationSynchronized CollaborationSynchronizedDelegate = NULL;

@interface ARSessionDelegateController ()

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) NSOperationQueue* motionQueue;
@property (nonatomic, strong) HandTracker* handTracker;
@property (assign) double lastHandTrackingTimestamp;

@property (nonatomic, strong) CMMotionManager* motionManager;

@property (nonatomic, strong) MultipeerSession *multipeerSession;
@property (assign) bool collaborationConnected;

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
        
        self.isLeftHandTracked = false;
        self.isRightHandTracked = false;
        self.lastHandTrackingTimestamp = [[NSProcessInfo processInfo] systemUptime];
        
        // MODIFY HERE
        self.isHandTrackingEnabled = YES;
        
        self.primaryButtonLeft = NO;
        self.primaryButtonRight = NO;
        
        // handler when receiving data
        void (^receivedDataHandler)(NSData *, MCPeerID *) = ^void(NSData *data, MCPeerID *peerID) {
            //NSLog(@"receivedDataHandler");
            // Try to decode the received data as ARCollaboration data.
            ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
            if (collaborationData != NULL) {
                [self.session updateWithCollaborationData:collaborationData];
                return;
            }
            // Try to decode the received data as peer hand position data.
            NSArray* decodedData = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:[NSNumber class] fromData:data error:nil];
            if (decodedData != NULL) {
                //NSLog(@"[ar_session]: peer hand position received: {%f, %f, %f}", [decodedData[0] floatValue], [decodedData[1] floatValue], [decodedData[2] floatValue]);
                UpdatePeerHandPositionDelegate([decodedData[0] floatValue], [decodedData[1] floatValue], [decodedData[2] floatValue]);
                return;
            }
            NSLog(@"[ar_session]: Failed to decode received data from peer.");
        };
        // Set up multipeer session
        self.multipeerSession = [[MultipeerSession alloc] initWithReceivedDataHandler:receivedDataHandler];
        self.collaborationConnected = false;
        
        //[self startAccelerometer];
        //[self startGyroscope];
        
        frame_count = 0;
        last_frame_time = 0.0f;
    }
    return self;
}

- (void)startAccelerometer {
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        self.motionManager.accelerometerUpdateInterval = 1.0 / 100.0;
        [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        //NSLog(@"[Accel] thread=%@, accelerometerData.timestamp=%f, systemuptime=%f, accelerometerData.acceleration.x=%f, accelerometerData.acceleration.y=%f, accelerometerData.acceleration.z=%f", [NSThread currentThread], accelerometerData.timestamp, [[NSProcessInfo processInfo] systemUptime], accelerometerData.acceleration.x, accelerometerData.acceleration.y, accelerometerData.acceleration.z);
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
    
    frame_count++;
    last_frame_time = frame.timestamp;
    
    //os_log_t log = os_log_create("com.DefaultCompany.Display", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    //os_signpost_id_t spid = os_signpost_id_generate(log);
    //os_signpost_interval_begin(log, spid, "session_didUpdateFrame", "frame_count: %d, last_frame_time: %f, system_uptime: %f", frame_count, last_frame_time, [[NSProcessInfo processInfo] systemUptime]);
    
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    if(self.session == NULL) {
        NSLog(@"[ar_session]: got ar session reference.");
        self.session = session;
    }
    
    // If hands are lost.
    if (self.isLeftHandTracked || self.isRightHandTracked) {
        float currentTimestamp = [[NSProcessInfo processInfo] systemUptime];
        if((currentTimestamp - self.lastHandTrackingTimestamp) > kLostHandTrackingInterval) {
            NSLog(@"[ar_session]: hand tracking lost.");
            self.isLeftHandTracked = false;
            self.isRightHandTracked = false;
        }
    }
    
    // Hand tracking
    if (self.isHandTrackingEnabled) {
        [self.handTrackingQueue addOperationWithBlock:^{
            [self.handTracker processVideoFrame: frame.capturedImage];
        }];
    }
    
    // Send my hand position to peers
    if (self.collaborationConnected && self.isLeftHandTracked) {
        LandmarkPosition *landmarkPosition = self.leftHandLandmarkPositions[0];
        NSArray* myHandPosition = [NSArray arrayWithObjects:
                                   [NSNumber numberWithFloat:landmarkPosition.x],
                                   [NSNumber numberWithFloat:landmarkPosition.y],
                                   [NSNumber numberWithFloat:landmarkPosition.z], nil];
        //NSLog(@"raw myHandPosition: {%f, %f, %f}", [myHandPosition[0] floatValue], [myHandPosition[1] floatValue], [myHandPosition[2] floatValue]);
        NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:myHandPosition requiringSecureCoding:YES error:nil];
        //NSArray* decodedData = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:[NSNumber class] fromData:encodedData error:nil];
        //NSLog(@"decoded myHandPosition: {%f, %f, %f}", [decodedData[0] floatValue], [decodedData[1] floatValue], [decodedData[2] floatValue]);
        [self.multipeerSession sendToAllPeers:encodedData];
    }
    
    //os_signpost_interval_end(log, spid, "session_didUpdateFrame");
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
    }
    //NSLog(@"[ar_session]: did add anchor.");
    for (ARAnchor *anchor in anchors) {
        // Check if this anchor is a new peer
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            NSLog(@"A new peer is connected into the collaboration session.");
            CollaborationSynchronizedDelegate();
            self.collaborationConnected = true;
            [self.session addAnchor:anchor];
            continue;
        }
        if (anchor.name != nil) {
            NSLog(@"[ar_session]: an anchor was added with name %@", anchor.name);
            if ([anchor.name isEqual:@"-1"]) {
                // This is an origin anchor.
                NSLog(@"[ar_session]: world origin was set according to the origin anchor.");
                [session setWorldOrigin:anchor.transform];
            }
            // This is a normal VFX anchor.
            std::vector<float> position = TransformToUnityPosition(anchor.transform);
            std::vector<float> rotation = TransformToUnityRotation(anchor.transform);
            //NSLog(@"anchor position: %f, %f, %f", position[0], position[1], position[2]);
            //NSLog(@"anchor rotation: %f, %f, %f, %f", rotation[0], rotation[1], rotation[2], rotation[3]);
            AnchorRevoke([anchor.name intValue], position[0], position[1], position[2],
                         rotation[0], rotation[1], rotation[2], rotation[3]);
        }
    }
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateAnchors:anchors];
    }
    //NSLog(@"[ar_session]: did update anchor.");
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
    //NSLog(@"didOutputCollaborationData");
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

- (bool)isBlooming:(NSArray<Landmark *> *)landmarks {
    if (landmarks[4].y < landmarks[3].y < landmarks[2].y < landmarks[1].y &&
        landmarks[8].y < landmarks[7].y < landmarks[6].y < landmarks[5].y &&
        landmarks[12].y < landmarks[11].y < landmarks[10].y < landmarks[9].y &&
        landmarks[16].y < landmarks[15].y < landmarks[14].y < landmarks[13].y &&
        landmarks[20].y < landmarks[19].y < landmarks[18].y < landmarks[17].y) {
        //NSLog(@"[ar_session]: blooming");
        return true;
    }
    return false;
}

// The uppeer-left corner is the origin of landmark xy coordinates
- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    //NSLog(@"[ar_session]: hands detected.");
    
    int handIndex = 0;
    for(NSArray<Landmark *> *landmarks in multiLandmarks) {
        // There cannot be more than 2 hands.
        if (handIndex > 1) {
            break;
        }
        int landmarkIndex = 0;
        float landmarkDepths[21];
        bool isHand = true;
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
                NSLog(@"[ar_session]: Failed to acquire scene depth.");
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
            // To make sure every landmark depth is reasonable.
            if (landmarkIndex == 0 && landmarkDepth > kMaxLandmarkDepth) {
                // The depth of the wrist is not reasonable, which means that
                // this result is false positive, abandon it.
                isHand = false;
                break;
            }
            if (landmarkIndex != 0) {
                int landmarkParentIndex = [ARSessionDelegateController getParentLandmarkIndex:landmarkIndex];
                if (landmarkDepth > kMaxLandmarkDepth) {
                    landmarkDepth = landmarkDepths[landmarkParentIndex];
                }
                if (landmarkIndex == 1 || landmarkIndex == 5 || landmarkIndex == 9 || landmarkIndex == 13 || landmarkIndex == 17) {
                    if (abs(landmarkDepth - landmarkDepths[landmarkParentIndex]) > kMaxLandmarkStartInterval) {
                        landmarkDepth = landmarkDepths[landmarkParentIndex];
                    }
                } else if (landmarkIndex == 2 || landmarkIndex == 6 || landmarkIndex == 10 || landmarkIndex == 14 || landmarkIndex == 18) {
                    if (abs(landmarkDepth - landmarkDepths[landmarkParentIndex]) > kMaxLandmark1Interval) {
                        landmarkDepth = landmarkDepths[landmarkParentIndex];
                    }
                } else if (landmarkIndex == 3 || landmarkIndex == 7 || landmarkIndex == 11 || landmarkIndex == 15 || landmarkIndex == 19) {
                    if (abs(landmarkDepth - landmarkDepths[landmarkParentIndex]) > kMaxLandmark2Interval) {
                        landmarkDepth = landmarkDepths[landmarkParentIndex];
                    }
                } else {
                    if (abs(landmarkDepth - landmarkDepths[landmarkParentIndex]) > kMaxLandmarkEndInterval) {
                        landmarkDepth = landmarkDepths[landmarkParentIndex];
                    }
                }
            }
            landmarkDepths[landmarkIndex] = landmarkDepth;

            simd_float3 unprojectedPoint = [self unprojectScreenPoint:screenPoint depth:landmarkDepth];
            LandmarkPosition *position = [[LandmarkPosition alloc] initWithX:unprojectedPoint.x y:unprojectedPoint.y z:unprojectedPoint.z];
            if (handIndex == 0) {
                [self.leftHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            } else if (handIndex == 1) {
                [self.rightHandLandmarkPositions replaceObjectAtIndex:landmarkIndex withObject:position];
            }
            landmarkIndex++;
        }
        if (isHand) {
            // Do hand gesture recognition using 2D landmarks
            // Temporarily, do it only on the left hand (it is actually the right hand for me...)
            bool isBlooming = [self isBlooming:landmarks];
            if (handIndex == 0) {
                self.primaryButtonLeft = isBlooming;
            } else if (handIndex == 1){
                self.primaryButtonRight = isBlooming;
            }
            handIndex++;
        }
    }
    if (handIndex == 0) {
        self.isLeftHandTracked = self.isRightHandTracked = false;
    } else {
        self.lastHandTrackingTimestamp = [[NSProcessInfo processInfo] systemUptime];
        if (handIndex == 1) {
            self.isLeftHandTracked = true;
            self.isRightHandTracked = false;
        } else if (handIndex == 2) {
            self.isLeftHandTracked = self.isRightHandTracked = true;
        }
    }
    //NSLog(@"[ar_session]: is left hand tracked: %d", self.isLeftHandTracked);
    //NSLog(@"[ar_session]: is right hand tracked: %d", self.isRightHandTracked);
}
    
+ (int)getParentLandmarkIndex:(int)landmarkIndex {
    int parentIndex;
    if (landmarkIndex == 0 || landmarkIndex == 5 || landmarkIndex == 9 || landmarkIndex == 13 || landmarkIndex == 17) {
        parentIndex = 0;
    } else{
        parentIndex = landmarkIndex - 1;
    }
    return parentIndex;
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
    simd_float4x4 transform_matrix = TransformFromUnity(position, rotation);
    
    ARSessionDelegateController* ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
    [ar_session_handler.session setWorldOrigin:(transform_matrix)];
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_AddNativeAnchor(int anchorId, float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = TransformFromUnity(position, rotation);
    
    ARAnchor* anchor = [[ARAnchor alloc] initWithName:[NSString stringWithFormat:@"%d", anchorId] transform:transform_matrix];
    ARSessionDelegateController* ar_session_handler = [ARSessionDelegateController sharedARSessionDelegateController];
    [ar_session_handler.session addAnchor:anchor];
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetAnchorRevoke(AnchorCallbackFunction callback) {
    NSLog(@"UnityHolokit_SetAnchorRevoke");
    AnchorRevoke = callback;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetUpdatePeerHandPositionDelegate(UpdatePeerHandPosition callback) {
    UpdatePeerHandPositionDelegate = callback;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetCollaborationSynchronizedDelegate(CollaborationSynchronized callback) {
    CollaborationSynchronizedDelegate = callback;
}
