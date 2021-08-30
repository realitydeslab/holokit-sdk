//
//  core_motion.m
//  core_motion
//
//  Created by Yuchen on 2021/8/30.
//

#import "core_motion.h"

@interface HoloKitCoreMotion()

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSOperationQueue* accelGyroQueue;
@property (nonatomic, strong) NSOperationQueue* deviceMotionQueue;

@end

@implementation HoloKitCoreMotion

- (instancetype)init {
    if (self = [super init]) {
        self.accelGyroQueue = [[NSOperationQueue alloc] init];
        self.accelGyroQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.deviceMotionQueue = [[NSOperationQueue alloc] init];
        self.deviceMotionQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionManager = [[CMMotionManager alloc] init];
    }
    return self;
}

+ (id)getSingletonInstance {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)startAccelerometer {
    
}

- (void)stopAccelerometer {
    
}

- (void)startGyroscope {
    
}

- (void)stopGyroscope {
    
}

- (void)startDeviceMotion {
    
}

- (void)stopDeviceMotion {
    
}

@end
