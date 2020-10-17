#import "sensors/ios/sensor_helper.h"

#import <QuartzCore/QuartzCore.h>

// iOS CMMotionManager updates actually happen at one of a set of intervals:
// 10ms, 20ms, 40ms, 80ms, 100ms, and so on, so best to use exactly one of the
// supported update intervals.
// Sample accelerometer and gyro every 10ms.
static const NSTimeInterval kAccelerometerUpdateInterval = 0.01;
static const NSTimeInterval kGyroUpdateInterval = 0.01;

@interface HoloKitSensorHelper ()
@property(atomic) CMAccelerometerData *accelerometerData;
@property(atomic) CMDeviceMotion *deviceMotion;
@end

#if __MACH__
@implementation HoloKitSensorHelper {
}
#else
@implementation HoloKitSensorHelper {
  CMMotionManager *_motionManager;
  NSOperationQueue *_queue;
  NSMutableSet *_accelerometerCallbacks;
  NSMutableSet *_deviceMotionCallbacks;
  NSLock *_accelerometerLock;
  NSLock *_deviceMotionLock;
}

+ (HoloKitSensorHelper *)sharedSensorHelper {
  static HoloKitSensorHelper *singleton;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    singleton = [[HoloKitSensorHelper alloc] init];
  });
  return singleton;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _motionManager = [[CMMotionManager alloc] init];

    _queue = [[NSOperationQueue alloc] init];
    // Tune these to your performance prefs.
    // maxConcurrent set to anything >1 crashes HoloKit SDK.
    _queue.maxConcurrentOperationCount = 1;
    if ([_queue respondsToSelector:@selector(setQualityOfService:)]) {
      // Use highest quality of service.
      _queue.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    _accelerometerCallbacks = [[NSMutableSet alloc] init];
    _deviceMotionCallbacks = [[NSMutableSet alloc] init];

    _accelerometerLock = [[NSLock alloc] init];
    _deviceMotionLock = [[NSLock alloc] init];
  }
  return self;
}

- (void)start:(SensorHelperType)type callback:(void (^)(void))callback {
  switch (type) {
    case SensorHelperTypeAccelerometer: {
      [self
          invokeBlock:^{
            [_accelerometerCallbacks addObject:callback];
          }
             withLock:_accelerometerLock];

      if (_motionManager.isAccelerometerActive) break;

      _motionManager.accelerometerUpdateInterval = kAccelerometerUpdateInterval;
      [_motionManager
          startAccelerometerUpdatesToQueue:_queue
                               withHandler:^(CMAccelerometerData *accelerometerData,
                                             NSError *error) {
                                 if (self.accelerometerData.timestamp !=
                                     accelerometerData.timestamp) {
                                   self.accelerometerData = accelerometerData;
                                   [self
                                       invokeBlock:^{
                                         for (void (^callback)(void) in _accelerometerCallbacks) {
                                           callback();
                                         }
                                       }
                                          withLock:_accelerometerLock];
                                 }
                               }];
    } break;

    case SensorHelperTypeGyro: {
      [self
          invokeBlock:^{
            [_deviceMotionCallbacks addObject:callback];
          }
             withLock:_deviceMotionLock];

      if (_motionManager.isDeviceMotionActive) break;

      _motionManager.deviceMotionUpdateInterval = kGyroUpdateInterval;
      [_motionManager
          startDeviceMotionUpdatesToQueue:_queue
                              withHandler:^(CMDeviceMotion *motionData, NSError *error) {
                                if (self.deviceMotion.timestamp != motionData.timestamp) {
                                  self.deviceMotion = motionData;
                                  [self
                                      invokeBlock:^{
                                        for (void (^callback)(void) in _deviceMotionCallbacks) {
                                          callback();
                                        }
                                      }
                                         withLock:_deviceMotionLock];
                                }
                              }];
    } break;
  }
}

- (void)stop:(SensorHelperType)type callback:(void (^)(void))callback {
  switch (type) {
    case SensorHelperTypeAccelerometer: {
      [self
          invokeBlock:^{
            [_accelerometerCallbacks removeObject:callback];
          }
             withLock:_accelerometerLock];
      if (_accelerometerCallbacks.count == 0) {
        [_motionManager stopAccelerometerUpdates];
      }
    } break;

    case SensorHelperTypeGyro: {
      [self
          invokeBlock:^{
            [_deviceMotionCallbacks removeObject:callback];
          }
             withLock:_deviceMotionLock];
      if (_deviceMotionCallbacks.count == 0) {
        [_motionManager stopDeviceMotionUpdates];
      }
    } break;
  }
}

- (BOOL)isAccelerometerAvailable {
  return [_motionManager isAccelerometerAvailable];
}

- (BOOL)isGyroAvailable {
  return [_motionManager isDeviceMotionAvailable];
}

- (void)invokeBlock:(void (^)(void))block withLock:(NSLock *)lock {
  [lock lock];
  block();
  [lock unlock];
}
#endif
@end
