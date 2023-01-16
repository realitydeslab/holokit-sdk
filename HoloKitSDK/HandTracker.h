//
//  HandTrackingController.h
//  holokit
//
//  Created by Yuchen Zhang on 2022/6/27.
//

#import <Vision/Vision.h>
#import <ARKit/ARKit.h>

@interface HandTracker : NSObject

@property (assign) BOOL active;

+ (id)sharedInstance;
- (void)performHumanHandPoseRequest:(ARFrame *)frame;

@end
