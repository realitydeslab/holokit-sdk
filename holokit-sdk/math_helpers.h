//
//  math_helpers.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include <simd/simd.h>
#include "UnityXRTypes.h"

double GetCurrentTime();

void LogMatrix4x4(simd_float4x4 mat);

simd_float4 MatrixVectorMultiplication(simd_float4x4 mat, simd_float4 vec);

UnityXRMatrix4x4 Float4x4ToUnityXRMatrix(simd_float4x4 simd_matrix);

UnityXRRectf Float4ToUnityXRRect(simd_float4 in_float4);

UnityXRPose EyePositionToUnityXRPose(simd_float3 eye_position);