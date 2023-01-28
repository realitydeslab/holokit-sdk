#import <Vision/Vision.h>
#import <ARKit/ARKit.h>

@interface HandTracker : NSObject

@property (assign) BOOL isActive;

+ (id)sharedInstance;
- (void)performHumanHandPoseRequest:(ARFrame *)frame;

@end
