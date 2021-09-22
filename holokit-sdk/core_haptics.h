//
//  core_haptics.h
//  core_haptics
//
//  Created by Yuchen on 2021/9/18.
//

#ifndef core_haptics_h
#define core_haptics_h

#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

@interface HoloKitHaptics : NSObject

@property (nonatomic, assign) BOOL supportsHaptics;

+ (id)sharedHaptics;

@end

#endif /* core_haptics_h */
