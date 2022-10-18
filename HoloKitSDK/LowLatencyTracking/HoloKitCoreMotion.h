//
//  HoloKitCoreMotion.h
//  holokit
//
//  Created by Botao Hu on 10/16/22.
//

#ifndef HoloKitCoreMotion_h
#define HoloKitCoreMotion_h

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

