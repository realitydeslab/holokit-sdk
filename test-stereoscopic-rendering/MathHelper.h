//
//  MathHelper.h
//  holokit
//
//  Created by Yuchen on 2021/2/22.
//

#ifndef MathHelper_h
#define MathHelper_h


#endif /* MathHelper_h */

@interface MathHelper : NSObject

// did not find any built-in function to do this
+ (simd_float4)matrixVectorMultiplication:(simd_float4x4)mat vector:(simd_float4)vec;

// log a simd_float4 onto the console
+ (void)logVector4:(simd_float4)vec;

// log a simd_float4x4 matrix onto the console
+ (void)logMatrix4x4:(simd_float4x4)mat;

@end
