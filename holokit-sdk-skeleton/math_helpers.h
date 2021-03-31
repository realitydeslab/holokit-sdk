//
//  math_helpers.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#import <simd/simd.h>

double GetCurrentTime();

void LogMatrix4x4(simd_float4x4 mat);

simd_float4 MatrixVectorMultiplication(simd_float4x4 mat, simd_float4 vec);
