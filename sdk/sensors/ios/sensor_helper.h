#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SensorHelperType) {
  SensorHelperTypeAccelerometer,
  SensorHelperTypeGyro,
};

// Helper class for running an arbitrary function on the CADisplayLink run loop.
@interface HoloKitSensorHelper : NSObject

+ (HoloKitSensorHelper*)sharedSensorHelper;

@property(readonly, nonatomic, getter=isAccelerometerAvailable) BOOL accelerometerAvailable;
@property(readonly, nonatomic, getter=isGyroAvailable) BOOL gyroAvailable;

@property(readonly, atomic) CMAccelerometerData* accelerometerData;
@property(readonly, atomic) CMDeviceMotion* deviceMotion;

// Starts the sensor callback.
- (void)start:(SensorHelperType)type callback:(void (^)(void))callback;

// Stops the sensor callback.
- (void)stop:(SensorHelperType)type callback:(void (^)(void))callback;

@end
