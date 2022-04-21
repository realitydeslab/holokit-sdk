//
//  core_location.h
//  core_location
//
//  Created by Yuchen on 2021/8/31.
//

#ifndef core_location_h
#define core_location_h

#import <CoreLocation/CoreLocation.h>

@interface HoloKitCoreLocation: NSObject

- (void)startUpdatingLocation;

- (void)stopUpdatingLocation;

- (void)startUpdatingHeading;

- (void)stopUpdatingHeading;

+ (id)sharedInstance;

@end

#endif /* core_location_h */
