//
//  math_helpers.m
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#import <Foundation/Foundation.h>
#import "math_helpers.h"

double GetCurrentTime() {
    return [[NSProcessInfo processInfo] systemUptime];
}
