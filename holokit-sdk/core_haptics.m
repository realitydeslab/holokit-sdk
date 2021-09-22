//
//  core_haptics.m
//  core_haptics
//
//  Created by Yuchen on 2021/9/18.
//

#import "core_haptics.h"

@interface HoloKitHaptics()

@property (nonatomic, strong) CHHapticEngine *hapticEngine;

@end

@implementation HoloKitHaptics

- (instancetype)init {
    if (self = [super init]) {
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware.supportsHaptics;
        if (self.supportsHaptics) {
            NSError *error;
            self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
        }
    }
    return self;
}

+ (id)sharedHaptics {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

@end
