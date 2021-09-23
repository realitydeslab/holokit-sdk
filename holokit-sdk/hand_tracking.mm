//
//  hand_tracking.m
//  hand_tracking
//
//  Created by Yuchen on 2021/9/17.
//

#import "hand_tracking.h"
#import <HandTracker/HandTracker.h>
#import <CoreVideo/CoreVideo.h>
#import "math_helpers.h"
#import "holokit_api.h"
#import "ar_session.h"
#import "IUnityInterface.h"

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
//static const float kLostHandTrackingInterval = 1.5f;

@interface HoloKitHandTracker() <TrackerDelegate>

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) HandTracker* handTracker;
@property (assign) double lastHandTrackingTimestamp;
@property (nonatomic, strong) VNDetectHumanHandPoseRequest *handPoseRequest;
@property (assign) int frameCount;

@end

@implementation HoloKitHandTracker

- (instancetype)init {
    if (self = [super init]) {
        //        self.handTracker = [[HandTracker alloc] init];
        //        self.handTracker.delegate = self;
        //        [self.handTracker startGraph];
        //        self.handTrackingQueue = [[NSOperationQueue alloc] init];
        //        self.handTrackingQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        // Vision hand tracking
        //self.handPoseRequest = [[VNDetectHumanHandPoseRequest alloc] init];
        // TODO: This value can be changed to one to save performance.
        //self.handPoseRequest.maximumHandCount = 2;
        //self.handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1;
        
        self.frameCount = 0;
        self.handPosePredictionInterval = 8;
        
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
    }
    return self;
}

+ (id)sharedHandTracker {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (simd_float3)unprojectScreenPoint:(CGPoint)screenPoint depth:(float)z {
    ARSession *arSession = [[HoloKitARSession sharedARSession] arSession];
    
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    simd_float4x4 planeOrigin = simd_mul(arSession.currentFrame.camera.transform, translation);
    simd_float3 xAxis = simd_make_float3(1, 0, 0);
    simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
    simd_float4x4 plane = simd_mul(planeOrigin, rotation);
    simd_float3 unprojectedPoint = [arSession.currentFrame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:arSession.currentFrame.camera.imageResolution];
    
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

- (int)humanHandPoseKeyToIndex:(NSString *)key {
    int index = 0;
    if ([key isEqual:VNHumanHandPoseObservationJointNameWrist]) {
        index = 0;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameThumbCMC]) {
        index = 1;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameThumbMP]) {
        index = 2;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameThumbIP]) {
        index = 3;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameThumbTip]) {
        index = 4;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameIndexMCP]) {
        index = 5;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameIndexPIP]) {
        index = 6;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameIndexDIP]) {
        index = 7;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameIndexTip]) {
        index = 8;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameMiddleMCP]) {
        index = 9;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameMiddlePIP]) {
        index = 10;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameMiddleDIP]) {
        index = 11;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameMiddleTip]) {
        index = 12;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameRingMCP]) {
        index = 13;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameRingPIP]) {
        index = 14;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameRingDIP]) {
        index = 15;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameRingTip]) {
        index = 16;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameLittleMCP]) {
        index = 17;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameLittlePIP]) {
        index = 18;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameLittleDIP]) {
        index = 19;
    } else if ([key isEqual:VNHumanHandPoseObservationJointNameLittleTip]) {
        index = 20;
    }
    return index;
}

- (VNRecognizedPointKey)landmarkIndexToHumanHandPoseKey:(int)landmarkIndex {
    VNRecognizedPointKey result = VNHumanHandPoseObservationJointNameWrist;
    switch(landmarkIndex) {
        case 1:
            result = VNHumanHandPoseObservationJointNameThumbCMC;
            break;
        case 2:
            result = VNHumanHandPoseObservationJointNameThumbMP;
            break;
        case 3:
            result = VNHumanHandPoseObservationJointNameThumbIP;
            break;
        case 4:
            result = VNHumanHandPoseObservationJointNameThumbTip;
            break;
        case 5:
            result = VNHumanHandPoseObservationJointNameIndexMCP;
            break;
        case 6:
            result = VNHumanHandPoseObservationJointNameIndexPIP;
            break;
        case 7:
            result = VNHumanHandPoseObservationJointNameIndexDIP;
            break;
        case 8:
            result = VNHumanHandPoseObservationJointNameIndexTip;
            break;
        case 9:
            result = VNHumanHandPoseObservationJointNameMiddleMCP;
            break;
        case 10:
            result = VNHumanHandPoseObservationJointNameMiddlePIP;
            break;
        case 11:
            result = VNHumanHandPoseObservationJointNameMiddleDIP;
            break;
        case 12:
            result = VNHumanHandPoseObservationJointNameMiddleTip;
            break;
        case 13:
            result = VNHumanHandPoseObservationJointNameRingMCP;
            break;
        case 14:
            result = VNHumanHandPoseObservationJointNameRingPIP;
            break;
        case 15:
            result = VNHumanHandPoseObservationJointNameRingDIP;
            break;
        case 16:
            result = VNHumanHandPoseObservationJointNameRingTip;
            break;
        case 17:
            result = VNHumanHandPoseObservationJointNameLittleMCP;
            break;
        case 18:
            result = VNHumanHandPoseObservationJointNameLittlePIP;
            break;
        case 19:
            result = VNHumanHandPoseObservationJointNameLittleDIP;
            break;
        case 20:
            result = VNHumanHandPoseObservationJointNameLittleTip;
            break;
        default:
            break;
    }
    return result;
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

- (void)performHumanHandPoseRequest:(ARFrame *)frame {
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc]
                                             initWithCVPixelBuffer: frame.capturedImage
                                             orientation:kCGImagePropertyOrientationUp options:[NSMutableDictionary dictionary]];
    @try {
        // There is on funcion in request handler to perform a single request...
        NSArray<VNRequest *> * requests = [[NSArray alloc] initWithObjects:self.handPoseRequest, nil];
        [requestHandler performRequests:requests error:nil];
        // Get the results.
        int numOfHands = self.handPoseRequest.results.count;
        //NSLog(@"[ar_session]: number of hand %d", numOfHands);
        if (numOfHands == 0) {
            // There is no hand in this frame.
            self.isLeftHandTracked = self.isRightHandTracked = false;
            return;
        }
        if (numOfHands == 1) {
            self.isLeftHandTracked = true;
            self.isRightHandTracked = false;
        } else {
            self.isLeftHandTracked = self.isRightHandTracked = true;
        }
    
        // Acquire scene depth.
        ARDepthData* sceneDepth = frame.sceneDepth;
        if (sceneDepth == nil) {
            NSLog(@"[ar_session]: failed to acquire scene depth.");
            return;
        }
        CVPixelBufferRef depthBuffer = sceneDepth.depthMap;
        CVPixelBufferLockBaseAddress(depthBuffer, 0);
        size_t depthBufferWidth = CVPixelBufferGetWidth(depthBuffer);
        size_t depthBufferHeight = CVPixelBufferGetHeight(depthBuffer);
        Float32 *depthBufferBaseAddress = (Float32*)CVPixelBufferGetBaseAddress(depthBuffer);
        // Go through all detected hands
        for (int handIndex = 0; handIndex < numOfHands; handIndex++) {
            VNHumanHandPoseObservation *handPoseObservation = self.handPoseRequest.results[handIndex];
            if (handPoseObservation == nil) {
                // Failed to perform request.
                return;
            }
            // TODO: the accuracy of chirality might be improved in the future.
            //NSLog(@"chirality %d", handPoseObservation.chirality);
            //NSLog(@"confidence %f", handPoseObservation.confidence);
            NSDictionary<VNRecognizedPointKey, VNRecognizedPoint*>* landmarks = [handPoseObservation recognizedPointsForGroupKey:VNRecognizedPointGroupKeyAll error:nil];
            float landmarkDepths[21];
            // Go through all hand landmakrs
            for(int landmarkIndex = 0; landmarkIndex < 21; landmarkIndex++) {
                VNRecognizedPointKey key = [self landmarkIndexToHumanHandPoseKey:landmarkIndex];
                // Landmark's x and y coordinate are originated from bottom-left corner
                // and is within 0 and 1.
                // The y is reverted compared to Google Mediapipe landmark.
                VNRecognizedPoint *landmark = [landmarks objectForKey:key];
                //NSLog(@"landmark: %f, %f", landmark.x, landmark.y);
                
                // Calculte the screen space coordinate of this point.
                int screenX = (CGFloat)landmark.x * frame.camera.imageResolution.width;
                int screenY = (CGFloat)(1 - landmark.y) * frame.camera.imageResolution.height;
                CGPoint screenPoint = CGPointMake(screenX, screenY);
                
                // Calculate the coordinate of this point in depth buffer space.
                int depthX = landmark.x * depthBufferWidth;
                int depthY = (1 - landmark.y) * depthBufferHeight;
                float landmarkDepth = depthBufferBaseAddress[depthY * depthBufferWidth + depthX];
                //landmarkDepth -= 0.05f;
                
                // Depth validation to eliminate false positive results.
                if (landmarkIndex == 0 && landmarkDepth > kMaxLandmarkDepth) {
                    // The depth of the wrist is not reasonable, which means that
                    // this result is false positive, abandon it.
                    break;
                }
                if (landmarkIndex != 0) {
                    int landmarkParentIndex = [HoloKitHandTracker getParentLandmarkIndex:landmarkIndex];
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
            }
        }
    } @catch(NSException * e) {
        NSLog(@"Vision hand tracking updating failed.");
    }
}

// The uppeer-left corner is the origin of landmark xy coordinates
- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    ARSession *arSession = [[HoloKitARSession sharedARSession] arSession];
    
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
            
            int x = (CGFloat)landmark.x * arSession.currentFrame.camera.imageResolution.width;
            int y = (CGFloat)landmark.y * arSession.currentFrame.camera.imageResolution.height;
            CGPoint screenPoint = CGPointMake(x, y);
            
            //NSLog(@"landmark [%f, %f]", landmark.x, landmark.y);
            size_t depthBufferWidth;
            size_t depthBufferHeight;
            Float32* depthBufferBaseAddress;
            ARDepthData* sceneDepth = arSession.currentFrame.sceneDepth;
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
                int landmarkParentIndex = [HoloKitHandTracker getParentLandmarkIndex:landmarkIndex];
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

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses {
    
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer { }

- (float)euclideanDistance:(simd_float2)point1 point2:(simd_float2)point2 {
    return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2));
}

@end

@implementation LandmarkPosition

- (instancetype)initWithX:(float)x y:(float)y z:(float)z {
    self = [super init];
    self.x = x;
    self.y = y;
    self.z = z;
    
    return self;
}

@end

extern "C" {

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_EnableHandTracking(bool enabled) {
    HoloKitHandTracker* hand_tracker = [HoloKitHandTracker sharedHandTracker];
    hand_tracker.isHandTrackingEnabled = enabled;
    NSLog(@"[ar_session]: EnableHandTracking(%d)", enabled);
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetHandTrackingInterval(int val) {
    HoloKitHandTracker* hand_tracker = [HoloKitHandTracker sharedHandTracker];
    [hand_tracker setHandPosePredictionInterval:val];
}

}