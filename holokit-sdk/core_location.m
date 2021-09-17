//
//  core_location.m
//  core_location
//
//  Created by Yuchen on 2021/8/31.
//

#import "core_location.h"
#include "IUnityInterface.h"

typedef void (*DidUpdateLocation)(double latitude, double longtitude, double altitude);
DidUpdateLocation DidUpdateLocationDelegate = NULL;

typedef void (*DidUpdateHeading)(double trueHeading, double magneticHeading, double headingAccuracy);
DidUpdateHeading DidUpdateHeadingDelegate = NULL;

@interface HoloKitCoreLocation() <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) CLHeading *currentHeading;

@end

@implementation HoloKitCoreLocation

- (instancetype)init {
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc] init];
        // TODO: Adjust this.
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.delegate = self;
        [self.locationManager requestWhenInUseAuthorization];
    }
    return self;
}

+ (id)sharedCoreLocation {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)startUpdatingLocation {
    [self.locationManager startUpdatingLocation];
}

- (void)stopUpdatingLocation {
    [self.locationManager stopUpdatingLocation];
}

- (void)startUpdatingHeading {
    [self.locationManager startUpdatingHeading];
}

- (void)stopUpdatingHeading {
    [self.locationManager stopUpdatingHeading];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (locations[0] != nil) {
        self.currentLocation = locations[0];
        DidUpdateLocationDelegate(self.currentLocation.coordinate.latitude, self.currentLocation.coordinate.longitude, self.currentLocation.altitude);
        [manager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (newHeading != nil) {
        self.currentHeading = newHeading;
        DidUpdateHeadingDelegate(self.currentHeading.trueHeading, self.currentHeading.magneticHeading, self.currentHeading.headingAccuracy);
        [manager stopUpdatingHeading];
    }
}

@end

#pragma mark - extern "C"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_StartUpdatingLocation(void) {
    HoloKitCoreLocation *instance = [HoloKitCoreLocation sharedCoreLocation];
    [instance.locationManager startUpdatingLocation];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_StartUpdatingHeading(void) {
    HoloKitCoreLocation *instance = [HoloKitCoreLocation sharedCoreLocation];
    [instance.locationManager startUpdatingHeading];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidUpdateLocationDelegate(DidUpdateLocation callback) {
    DidUpdateLocationDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidUpdateHeadingDelegate(DidUpdateHeading callback) {
    DidUpdateHeadingDelegate = callback;
}

