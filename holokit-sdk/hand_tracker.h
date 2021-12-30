//
//  hand_tracking.h
//  hand_tracking
//
//  Created by Yuchen on 2021/9/17.
//

#ifndef hand_tracking_h
#define hand_tracking_h

#import <Foundation/Foundation.h>

@interface LandmarkPosition : NSObject

@property (assign) float x;
@property (assign) float y;
@property (assign) float z;

- (instancetype)initWithX:(float)x y:(float)y z:(float)z;

@end

@interface HandTracker : NSObject

@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *leftHandLandmarkPositions;
@property (nonatomic, strong, nullable) NSMutableArray<LandmarkPosition *> *rightHandLandmarkPositions;
@property (assign) bool isHandTrackingEnabled;
@property (assign) bool isLeftHandTracked;
@property (assign) bool isRightHandTracked;
@property (assign) int handPosePredictionInterval;

+ (id)sharedHandTracker;

@end

#endif /* hand_tracking_h */
