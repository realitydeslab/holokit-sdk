//
//  core_motion.h
//  core_motion
//
//  Created by Yuchen on 2021/8/30.
//

#ifndef core_motion_h
#define core_motion_h

#import <CoreMotion/CoreMotion.h>

@interface HoloKitCoreMotion: NSObject

@property (nonatomic, strong) CMAccelerometerData *currentAccelData;
@property (nonatomic, strong) CMGyroData *currentGyroData;
@property (nonatomic, strong) CMDeviceMotion *currentDeviceMotion;

- (void)startAccelerometer;
- (void)stopAccelerometer;
- (void)startGyroscope;
- (void)stopGyroscope;
- (void)startDeviceMotion;
- (void)stopDeviceMotion;

+ (id)getSingletonInstance;

@end

#endif /* core_motion_h */