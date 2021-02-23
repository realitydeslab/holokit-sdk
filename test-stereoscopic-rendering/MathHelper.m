//
//  MathHelper.m
//  test-stereoscopic-rendering
//
//  Created by Yuchen on 2021/2/22.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

#import "MathHelper.h"

@implementation MathHelper

+ (simd_float4)matrixVectorMultiplication:(simd_float4x4)mat vector:(simd_float4)vec {
    simd_float4 ret;
    ret.x = mat.columns[0].x * vec.x + mat.columns[1].x * vec.y + mat.columns[2].x * vec.z + mat.columns[3].x * vec.w;
    ret.y = mat.columns[0].y * vec.x + mat.columns[1].y * vec.y + mat.columns[2].y * vec.z + mat.columns[3].y * vec.w;
    ret.z = mat.columns[0].z * vec.x + mat.columns[1].z * vec.y + mat.columns[2].z * vec.z + mat.columns[3].z * vec.w;
    ret.w = mat.columns[0].w * vec.x + mat.columns[1].w * vec.y + mat.columns[2].w * vec.z + mat.columns[3].w * vec.w;
    return ret;
}

+ (void)logVector4:(simd_float4)vec {
    NSLog(@"simd_float4: [%f %f %f %f]", vec.x, vec.y, vec.z, vec.w);
}

// print out the matrix column by column
+ (void)logMatrix4x4:(simd_float4x4)mat {
    NSLog(@"simd_float4x4;");
    NSLog(@"[%f %f %f %f]", mat.columns[0].x, mat.columns[0].y, mat.columns[0].z, mat.columns[0].w);
    NSLog(@"[%f %f %f %f]", mat.columns[1].x, mat.columns[1].y, mat.columns[1].z, mat.columns[1].w);
    NSLog(@"[%f %f %f %f]", mat.columns[2].x, mat.columns[2].y, mat.columns[2].z, mat.columns[2].w);
    NSLog(@"[%f %f %f %f]", mat.columns[3].x, mat.columns[3].y, mat.columns[3].z, mat.columns[3].w);
}

@end
