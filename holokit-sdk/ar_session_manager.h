//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//
#pragma once
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>
#import "multipeer_session.h"
#import "ar_recorder.h"

@interface ARSessionManager : NSObject

@property (nonatomic, strong, nullable) ARSession* arSession;
@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) MultipeerSession *multipeerSession;
// For Apple Watch input device
@property (assign) bool appleWatchIsTracked;
@property (nonatomic, assign) simd_quatd appleWatchRotation;
@property (nonatomic, assign) simd_double3 appleWatchAcceleration;
@property (nonatomic, assign) simd_double3 appleWatchAngularVelocity;
@property (nonatomic, strong, nullable) CADisplayLink *aDisplayLink;
@property (nonatomic, assign) double lastVsyncTimestamp;
@property (nonatomic, assign) double nextVsyncTimestamp;
@property (assign) BOOL isUsingARWorldMap;

+ (id _Nonnull )sharedARSessionManager;
- (void)updateWithCollaborationData:(ARCollaborationData *_Nonnull) collaborationData;

@end
