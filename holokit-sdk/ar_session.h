//
//  ar_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/8.
//
#import <ARKit/ARKit.h>

@interface ARSessionDelegateController : NSObject

@property (nonatomic, strong, nullable) ARSession* arSession;
@property (nonatomic, strong, nullable) ARWorldMap *worldMap;

+ (id _Nonnull)sharedInstance;
- (void)updateWithCollaborationData:(ARCollaborationData *_Nonnull) collaborationData;

@end
