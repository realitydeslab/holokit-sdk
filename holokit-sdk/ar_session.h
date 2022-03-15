//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//
#import <ARKit/ARKit.h>
#import "multipeer_session.h"

@interface ARSessionDelegateController : NSObject

@property (nonatomic, strong, nullable) ARSession* arSession;
@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) MultipeerSession *multipeerSession;
@property (assign) BOOL isScanningARWorldMap;
@property (nonatomic, strong, nullable) ARWorldMap *worldMap;

+ (id _Nonnull)sharedARSessionDelegateController;
- (void)updateWithCollaborationData:(ARCollaborationData *_Nonnull) collaborationData;
- (void)setIsStereoscopicRendering:(BOOL)val;

@end
