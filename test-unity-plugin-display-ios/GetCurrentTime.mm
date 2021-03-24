//
//  GetCurrentTime.m
//  test-unity-plugin-display-ios
//
//  Created by Yuchen on 2021/3/16.
//

#import <Foundation/Foundation.h>
#import "GetCurrentTime.h"

double getCurrentTime() {
    return [[NSProcessInfo processInfo] systemUptime];
}
