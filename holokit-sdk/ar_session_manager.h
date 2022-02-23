//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>
#import "multipeer_session.h"

@interface ARSessionManager : NSObject

@property (nonatomic, strong, nullable) ARSession* arSession;
@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) MultipeerSession *multipeerSession;
@property (nonatomic, strong, nullable) CADisplayLink *aDisplayLink;
@property (nonatomic, assign) double lastVsyncTimestamp;
@property (nonatomic, assign) double nextVsyncTimestamp;
@property (assign) BOOL isScanningARWorldMap;
@property (nonatomic, strong, nullable) ARWorldMap *worldMap;

+ (id _Nonnull )sharedARSessionManager;
- (void)updateWithCollaborationData:(ARCollaborationData *_Nonnull) collaborationData;
- (void)setIsStereoscopicRendering:(BOOL)val;

@end
