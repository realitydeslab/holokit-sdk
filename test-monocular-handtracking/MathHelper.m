//
//  MathHelper.m
//  test-monocular-handtracking
//
//  Created by Yuchen on 2021/2/22.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

#import "MathHelper.h"

@implementation MathHelper

// print out the matrix column by column
+ (void)logMatrix4x4:(simd_float4x4)mat {
    //NSLog(@"simd_float4x4;");
    NSLog(@"[%f %f %f %f]", mat.columns[0].x, mat.columns[0].y, mat.columns[0].z, mat.columns[0].w);
    NSLog(@"[%f %f %f %f]", mat.columns[1].x, mat.columns[1].y, mat.columns[1].z, mat.columns[1].w);
    NSLog(@"[%f %f %f %f]", mat.columns[2].x, mat.columns[2].y, mat.columns[2].z, mat.columns[2].w);
    NSLog(@"[%f %f %f %f]", mat.columns[3].x, mat.columns[3].y, mat.columns[3].z, mat.columns[3].w);
}

@end
