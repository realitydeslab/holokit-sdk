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
#import <CoreMotion/CoreMotion.h>
#import "LandmarkPosition.h"

@interface ARSessionDelegateController : NSObject <ARSessionDelegate, TrackerDelegate>

@property (nonatomic, strong) NSOperationQueue* handTrackingQueue;
@property (nonatomic, strong) NSOperationQueue* motionQueue;
@property (nonatomic, strong) HandTracker* handTracker;
//@property (nonatomic, strong) NSArray<NSArray<Landmark *> *> *landmarks;
@property (nonatomic, strong) NSMutableArray<LandmarkPosition *> *leftHandLandmarkPositions;
@property (nonatomic, strong) NSMutableArray<LandmarkPosition *> *rightHandLandmarkPositions;
@property (assign) double lastHandTrackingTimestamp;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;
// open or close hand tracking
@property (assign) bool isHandTrackingEnabled;

@property (nonatomic, strong) ARSession* session;

@property (nonatomic, strong) CMMotionManager* motionManager;

+ (id) sharedARSessionDelegateController;

@end
