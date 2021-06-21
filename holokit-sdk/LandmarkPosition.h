//
//  LandmarkPosition.h
//  holokit
//
//  Created by Yuchen on 2021/3/8.
//

#import <Foundation/Foundation.h>

@interface LandmarkPosition : NSObject

@property (assign) float x;
@property (assign) float y;
@property (assign) float z;

- (instancetype)initWithX:(float)x y:(float)y z:(float)z;

@end
