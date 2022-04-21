//
//  hand_tracking.m
//  hand_tracking
//
//  Created by Yuchen on 2021/9/17.
//

#import "hand_tracker.h"
#import <CoreVideo/CoreVideo.h>
#import "math_helpers.h"
#import "holokit_api.h"
//#import "ar_session_manager.h"
#import "IUnityInterface.h"

static const float kMaxLandmarkDepth = 0.6f;
static const float kMaxLandmarkStartInterval = 0.12f;
static const float kMaxLandmark1Interval = 0.05f;
static const float kMaxLandmark2Interval = 0.03f;
static const float kMaxLandmarkEndInterval = 0.024f;
//static const float kLostHandTrackingInterval = 1.5f;

@interface HandTracker()

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (assign) double lastHandTrackingTimestamp;
@property (nonatomic, strong) VNDetectHumanHandPoseRequest *handPoseRequest;
@property (assign) int frameCount;

@end

@implementation HandTracker

- (instancetype)init {
    if (self = [super init]) {
        self.handPoseRequest = [[VNDetectHumanHandPoseRequest alloc] init];
        // This value can be changed to 1 to save performance.
        self.handPoseRequest.maximumHandCount = 2;
        self.handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1;
        
        self.frameCount = 0;
        self.handTrackingExecutionFrameInterval = 4;
        
        self.leftHandLandmarks = [[NSMutableArray alloc] init];
        self.rightHandLandmarks = [[NSMutableArray alloc] init];
        for(int i = 0; i < 21; i++){
            HandLandmark *position = [[HandLandmark alloc] initWithX:0.0 y:0.0 z:0.0];
            [self.leftHandLandmarks addObject:position];
            [self.rightHandLandmarks addObject:position];
        }
        
        self.isLeftHandTracked = false;
        self.isRightHandTracked = false;
        self.lastHandTrackingTimestamp = [[NSProcessInfo processInfo] systemUptime];

        self.isHandTrackingOn = NO;
    }
    return self;
}

+ (id)sharedInstance {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)performHumanHandPoseRequest:(ARFrame *)frame {
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc]
                                             initWithCVPixelBuffer: frame.capturedImage
                                             orientation:kCGImagePropertyOrientationUp options:[NSMutableDictionary dictionary]];
    self.frameCount++;
    if (self.frameCount % self.handTrackingExecutionFrameInterval != 0) return;
 
    @try {
        NSArray<VNRequest *> * requests = [[NSArray alloc] initWithObjects:self.handPoseRequest, nil];
        [requestHandler performRequests:requests error:nil];
        unsigned long numOfHands = self.handPoseRequest.results.count;
        if (numOfHands == 0) {
            // There is no hand in this frame
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
                // Failed to perform request
                return;
            }
            // TODO: the accuracy of chirality might be improved in the future.
//            NSLog(@"chirality %d", handPoseObservation.chirality);
//            NSLog(@"confidence %f", handPoseObservation.confidence);
            NSDictionary<VNRecognizedPointKey, VNRecognizedPoint*>* landmarks = [handPoseObservation recognizedPointsForGroupKey:VNRecognizedPointGroupKeyAll error:nil];
            float landmarkDepths[21];
            // Go through all hand landmakrs
            for(int landmarkIndex = 0; landmarkIndex < 21; landmarkIndex++) {
                VNRecognizedPointKey key = [HandTracker landmarkIndexToHumanHandPoseKey:landmarkIndex];
                // Landmark's x and y coordinate are originated from bottom-left corner
                // and is within 0 and 1.
                // The y is reverted compared to Google Mediapipe landmark.
                VNRecognizedPoint *landmark = [landmarks objectForKey:key];

                // Calculte the screen space coordinate of this point.
                int screenX = (CGFloat)landmark.x * frame.camera.imageResolution.width;
                int screenY = (CGFloat)(1 - landmark.y) * frame.camera.imageResolution.height;
                CGPoint screenPoint = CGPointMake(screenX, screenY);

                // Calculate the coordinate of this point in depth buffer space.
                int depthX = landmark.x * depthBufferWidth;
                int depthY = (1 - landmark.y) * depthBufferHeight;
                float landmarkDepth = depthBufferBaseAddress[depthY * depthBufferWidth + depthX];

                // Depth validation to eliminate false positive results.
                if (landmarkIndex == 0 && landmarkDepth > kMaxLandmarkDepth) {
                    // The depth of the wrist is not reasonable, which means that
                    // this result is false positive, abandon it.
                    break;
                }
                if (landmarkIndex != 0) {
                    int landmarkParentIndex = [HandTracker getParentLandmarkIndex:landmarkIndex];
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

                simd_float3 unprojectedPoint = [HandTracker unprojectScreenPoint:screenPoint depth:landmarkDepth frame:frame];
                HandLandmark *position = [[HandLandmark alloc] initWithX:unprojectedPoint.x y:unprojectedPoint.y z:unprojectedPoint.z];
                if (handIndex == 0) {
                    [self.leftHandLandmarks replaceObjectAtIndex:landmarkIndex withObject:position];
                } else if (handIndex == 1) {
                    [self.rightHandLandmarks replaceObjectAtIndex:landmarkIndex withObject:position];
                }
            }
        }
    } @catch(NSException * e) {
        NSLog(@"Vision hand tracking updating failed.");
    }
}

+ (simd_float3)unprojectScreenPoint:(CGPoint)screenPoint depth:(float)z frame:(ARFrame *)frame {
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    simd_float4x4 planeOrigin = simd_mul(frame.camera.transform, translation);
    simd_float3 xAxis = simd_make_float3(1, 0, 0);
    simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
    simd_float4x4 plane = simd_mul(planeOrigin, rotation);
    simd_float3 unprojectedPoint = [frame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:frame.camera.imageResolution];
    return unprojectedPoint;
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

+ (int)humanHandPoseKeyToIndex:(NSString *)key {
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

+ (VNRecognizedPointKey)landmarkIndexToHumanHandPoseKey:(int)landmarkIndex {
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

@end

@implementation HandLandmark

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
UnityHoloKit_TurnOnHandTracking() {
    [[HandTracker sharedInstance] setIsHandTrackingOn:YES];
    NSLog(@"[hand_tracker] did turn on hand tracking");
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_TurnOffHandTracking() {
    [[HandTracker sharedInstance] setIsHandTrackingOn:NO];
    NSLog(@"[hand_tracker] did turn off hand tracking");
}

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_IsHandTrackingOn(){
    return [[HandTracker sharedInstance] isHandTrackingOn];
}

}
