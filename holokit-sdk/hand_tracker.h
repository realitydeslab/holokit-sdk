//
//  hand_tracking.h
//  hand_tracking
//
//  Created by Yuchen on 2021/9/17.
//

#ifndef hand_tracking_h
#define hand_tracking_h

#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>

@interface HandLandmark : NSObject

@property (assign) float x;
@property (assign) float y;
@property (assign) float z;

- (instancetype)initWithX:(float)x y:(float)y z:(float)z;

@end

@interface HandTracker : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<HandLandmark *> *leftHandLandmarks;
@property (nonatomic, strong, nullable) NSMutableArray<HandLandmark *> *rightHandLandmarks;
@property (assign) bool isHandTrackingOn;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;
@property (assign) int handTrackingExecutionFrameInterval;

+ (id)sharedInstance;
- (void)performHumanHandPoseRequest:(ARFrame *)frame;

@end

#endif /* hand_tracking_h */
