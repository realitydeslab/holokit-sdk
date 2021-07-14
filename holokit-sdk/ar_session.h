//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//

#import <ARKit/ARKit.h>
#import <HandTracker/HandTracker.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMotion/CoreMotion.h>
#import "LandmarkPosition.h"
#import "multipeer_session.h"
#import <WatchConnectivity/WatchConnectivity.h>

@interface ARSessionDelegateController : NSObject

@property (nonatomic, strong, nullable) ARSession* session;
@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *leftHandLandmarkPositions;
@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *rightHandLandmarkPositions;
@property (assign) bool isHandTrackingEnabled;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;
@property (assign) bool primaryButtonLeft;
@property (assign) bool primaryButtonRight;
@property (assign) int handPosePredictionInterval;
@property (nonatomic, strong) MultipeerSession *multipeerSession;

+ (id)sharedARSessionDelegateController;

@end
