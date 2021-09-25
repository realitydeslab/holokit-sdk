//
//  core_motion.m
//  core_motion
//
//  Created by Yuchen on 2021/8/30.
//

#import "core_motion.h"
#import "low-latency-tracking/low_latency_tracking_api.h"
#import "math_helpers.h"

@interface HoloKitCoreMotion()

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSOperationQueue *accelGyroQueue;
@property (nonatomic, strong) NSOperationQueue *deviceMotionQueue;
@property (nonatomic, assign) double accelUpdateInterval;
@property (nonatomic, assign) double gyroUpdateInterval;
@property (nonatomic, assign) double deviceMotionUpdateInterval;

@end

@implementation HoloKitCoreMotion

- (instancetype)init {
    if (self = [super init]) {
        self.accelGyroQueue = [[NSOperationQueue alloc] init];
        self.accelGyroQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.deviceMotionQueue = [[NSOperationQueue alloc] init];
        self.deviceMotionQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.motionManager = [[CMMotionManager alloc] init];
        self.accelUpdateInterval = 1.0 / 120.0;
        self.gyroUpdateInterval = 1.0 / 120.0;
        self.deviceMotionUpdateInterval = 1.0 / 120.0;
    }
    return self;
}

+ (id)sharedCoreMotion {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)startAccelerometer:(void (^)(CMAccelerometerData *))handler {
    if ([self.motionManager isAccelerometerAvailable] && ![self.motionManager isAccelerometerActive]) {
        self.motionManager.accelerometerUpdateInterval = self.accelUpdateInterval;
        [self.motionManager startAccelerometerUpdatesToQueue:self.accelGyroQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            self.currentAccelData = accelerometerData;
            handler(accelerometerData);
        }];
    }
}

- (void)stopAccelerometer {
    if ([self.motionManager isAccelerometerAvailable] && [self.motionManager isAccelerometerActive]) {
        [self.motionManager stopAccelerometerUpdates];
    }
}

- (void)startGyroscope:(void (^)(CMGyroData *))handler {
    if ([self.motionManager isGyroAvailable] && ![self.motionManager isGyroActive]) {
        self.motionManager.gyroUpdateInterval = self.gyroUpdateInterval;
        [self.motionManager startGyroUpdatesToQueue:self.accelGyroQueue withHandler:^(CMGyroData *gyroData, NSError *error) {
            self.currentGyroData = gyroData;
            handler(gyroData);
        }];
    }
}

- (void)stopGyroscope {
    if ([self.motionManager isGyroAvailable] && [self.motionManager isGyroActive]) {
        [self.motionManager stopGyroUpdates];
    }
}

- (void)startDeviceMotion:(void (^)(CMDeviceMotion *))handler {
    if ([self.motionManager isDeviceMotionAvailable] && ![self.motionManager isDeviceMotionActive]) {
        self.motionManager.deviceMotionUpdateInterval = self.deviceMotionUpdateInterval;
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical toQueue:self.deviceMotionQueue withHandler:^(CMDeviceMotion *deviceMotion, NSError *error) {
            self.currentDeviceMotion = deviceMotion;
            handler(deviceMotion);
        }];
    }
}

- (void)stopDeviceMotion {
    if ([self.motionManager isDeviceMotionAvailable] && [self.motionManager isDeviceMotionActive]) {
        [self.motionManager stopDeviceMotionUpdates];
    }
}

@end
