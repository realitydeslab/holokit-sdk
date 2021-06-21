//
//  LandmarkPosition.m
//  test-unity-plugin-input
//
//  Created by Yuchen on 2021/3/8.
//


#import "LandmarkPosition.h"

@implementation LandmarkPosition

- (instancetype)initWithX:(float)x y:(float)y z:(float)z {
    self = [super init];
    self.x = x;
    self.y = y;
    self.z = z;
    
    return self;
}

@end
