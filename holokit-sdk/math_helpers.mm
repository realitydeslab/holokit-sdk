//
//  math_helpers.mm
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#import <Foundation/Foundation.h>
#import "math_helpers.h"

double GetCurrentTime() {
    return [[NSProcessInfo processInfo] systemUptime];
}

// print out the matrix column by column
void LogMatrix4x4(simd_float4x4 mat) {
    NSLog(@"simd_float4x4;");
    NSLog(@"[%f %f %f %f]", mat.columns[0].x, mat.columns[0].y, mat.columns[0].z, mat.columns[0].w);
    NSLog(@"[%f %f %f %f]", mat.columns[1].x, mat.columns[1].y, mat.columns[1].z, mat.columns[1].w);
    NSLog(@"[%f %f %f %f]", mat.columns[2].x, mat.columns[2].y, mat.columns[2].z, mat.columns[2].w);
    NSLog(@"[%f %f %f %f]", mat.columns[3].x, mat.columns[3].y, mat.columns[3].z, mat.columns[3].w);
}

simd_float4 MatrixVectorMultiplication(simd_float4x4 mat, simd_float4 vec) {
    simd_float4 ret;
    ret.x = mat.columns[0].x * vec.x + mat.columns[1].x * vec.y + mat.columns[2].x * vec.z + mat.columns[3].x * vec.w;
    ret.y = mat.columns[0].y * vec.x + mat.columns[1].y * vec.y + mat.columns[2].y * vec.z + mat.columns[3].y * vec.w;
    ret.z = mat.columns[0].z * vec.x + mat.columns[1].z * vec.y + mat.columns[2].z * vec.z + mat.columns[3].z * vec.w;
    ret.w = mat.columns[0].w * vec.x + mat.columns[1].w * vec.y + mat.columns[2].w * vec.z + mat.columns[3].w * vec.w;
    return ret;
}

UnityXRMatrix4x4 Float4x4ToUnityXRMatrix(simd_float4x4 simd_matrix) {
    UnityXRMatrix4x4 unity_matrix;
    unity_matrix.columns[0].x = simd_matrix.columns[0].x;
    unity_matrix.columns[0].y = simd_matrix.columns[0].y;
    unity_matrix.columns[0].z = simd_matrix.columns[0].z;
    unity_matrix.columns[0].w = simd_matrix.columns[0].w;
    
    unity_matrix.columns[1].x = simd_matrix.columns[1].x;
    unity_matrix.columns[1].y = simd_matrix.columns[1].y;
    unity_matrix.columns[1].z = simd_matrix.columns[1].z;
    unity_matrix.columns[1].w = simd_matrix.columns[1].w;
    
    unity_matrix.columns[2].x = simd_matrix.columns[2].x;
    unity_matrix.columns[2].y = simd_matrix.columns[2].y;
    unity_matrix.columns[2].z = simd_matrix.columns[2].z;
    unity_matrix.columns[2].w = simd_matrix.columns[2].w;
    
    unity_matrix.columns[3].x = simd_matrix.columns[3].x;
    unity_matrix.columns[3].y = simd_matrix.columns[3].y;
    unity_matrix.columns[3].z = simd_matrix.columns[3].z;
    unity_matrix.columns[3].w = simd_matrix.columns[3].w;
    
    return unity_matrix;
}

UnityXRRectf Float4ToUnityXRRect(simd_float4 in_float4) {
    UnityXRRectf unity_rect;
    unity_rect.x = in_float4.x;
    unity_rect.y = in_float4.y;
    unity_rect.width = in_float4.z;
    unity_rect.height = in_float4.w;
    return unity_rect;
}

UnityXRPose EyePositionToUnityXRPose(simd_float3 eye_position) {
    UnityXRPose unity_pose;
    unity_pose.position = UnityXRVector3 { eye_position.x, eye_position.y, eye_position.z };
    unity_pose.rotation = UnityXRVector4 { 0, 0, 0, 1 };
    return unity_pose;
}
