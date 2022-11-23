//
//  Utils.h
//  holokit
//
//  Created by Yuchen Zhang on 2022/8/14.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

@interface Utils : NSObject

+ (simd_float4x4)getSimdFloat4x4WithPosition:(float [3])position rotation:(float [4])rotation;

+ (float *)getUnityMatrix:(simd_float4x4)arkitMatrix;

@end
