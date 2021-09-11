//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//
#pragma once
#import <ARKit/ARKit.h>
#import <HandTracker/HandTracker.h>
#import <CoreVideo/CoreVideo.h>
#import "LandmarkPosition.h"
#import "multipeer_session.h"
#import "ar_recorder.h"

@interface HoloKitARSession : NSObject

@property (nonatomic, strong, nullable) ARSession* arSession;
@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *leftHandLandmarkPositions;
@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *rightHandLandmarkPositions;
@property (assign) bool isHandTrackingEnabled;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;
@property (assign) bool primaryButtonLeft;
@property (assign) bool primaryButtonRight;
@property (assign) int handPosePredictionInterval;
@property (nonatomic, strong, nullable) MultipeerSession *multipeerSession;
@property (nonatomic, strong, nullable) HoloKitARRecorder *recorder;
@property (assign) bool isRecording;
// For Apple Watch input device
@property (assign) bool appleWatchIsTracked;
@property (nonatomic, assign) simd_quatd appleWatchRotation;
@property (nonatomic, assign) simd_double3 appleWatchAcceleration;
@property (nonatomic, assign) simd_double3 appleWatchAngularVelocity;
@property (nonatomic, strong, nullable) CADisplayLink *aDisplayLink;

+ (id)sharedARSession;
- (void)updateWithHoloKitCollaborationData:(ARCollaborationData *) collaborationData;

@end
