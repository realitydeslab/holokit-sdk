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
    unity_pose.position = UnityXRVector3 { eye_position.x, eye_position.y, -eye_position.z };
    unity_pose.rotation = UnityXRVector4 { 0, 0, 0, 1 };
    return unity_pose;
}

simd_float4x4 TransformFromUnity(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = matrix_identity_float4x4;
    float converted_rotation[4];
    // The structure of converted_rotation is { w, x, y, z }
    converted_rotation[0] = rotation[3];
    converted_rotation[1] = -rotation[0];
    converted_rotation[2] = -rotation[1];
    converted_rotation[3] = rotation[2];
    // Convert quaternion to rotation matrix
    // See: https://automaticaddison.com/how-to-convert-a-quaternion-to-a-rotation-matrix/
    transform_matrix.columns[0].x = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[1] * converted_rotation[1]) - 1;
    transform_matrix.columns[0].y = 2 * (converted_rotation[1] * converted_rotation[2] + converted_rotation[0] * converted_rotation[3]);
    transform_matrix.columns[0].z = 2 * (converted_rotation[1] * converted_rotation[3] - converted_rotation[0] * converted_rotation[2]);
    transform_matrix.columns[1].x = 2 * (converted_rotation[1] * converted_rotation[2] - converted_rotation[0] * converted_rotation[3]);
    transform_matrix.columns[1].y = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[2] * converted_rotation[2]) - 1;
    transform_matrix.columns[1].z = 2 * (converted_rotation[2] * converted_rotation[3] + converted_rotation[0] * converted_rotation[1]);
    transform_matrix.columns[2].x = 2 * (converted_rotation[1] * converted_rotation[3] + converted_rotation[0] * converted_rotation[2]);
    transform_matrix.columns[2].y = 2 * (converted_rotation[2] * converted_rotation[3] - converted_rotation[0] * converted_rotation[1]);
    transform_matrix.columns[2].z = 2 * (converted_rotation[0] * converted_rotation[0] + converted_rotation[3] * converted_rotation[3]) - 1;
    // Convert translate into matrix
    transform_matrix.columns[3].x = position[0];
    transform_matrix.columns[3].y = position[1];
    transform_matrix.columns[3].z = -position[2];
    return transform_matrix;
}

std::vector<float> TransformToUnityPosition(simd_float4x4 transform_matrix) {
    std::vector<float> position;
    position.push_back(transform_matrix.columns[3].x);
    position.push_back(transform_matrix.columns[3].y);
    // Unity is left-handed while ARKit is right-handed.
    position.push_back(-transform_matrix.columns[3].z);
    return position;
}

// TODO: I don't know if this will work
std::vector<float> TransformToUnityRotation(simd_float4x4 transform_matrix) {
    std::vector<float> rotation;
    simd_quatf quaternion = simd_quaternion(transform_matrix);
    rotation.push_back(quaternion.vector.x);
    rotation.push_back(quaternion.vector.y);
    rotation.push_back(quaternion.vector.z);
    rotation.push_back(quaternion.vector.w);
    return rotation;
}
