//
//  math_helpers.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//
#pragma once
#include <simd/simd.h>
#include <vector>
#include "UnityXRTypes.h"
#import <CoreMotion/CoreMotion.h>
#include <Eigen/Core>
#include <Eigen/Geometry>

double GetCurrentTime();

void LogMatrix4x4(simd_float4x4 mat);

simd_float4 MatrixVectorMultiplication(simd_float4x4 mat, simd_float4 vec);

UnityXRMatrix4x4 Float4x4ToUnityXRMatrix(simd_float4x4 simd_matrix);

UnityXRRectf Float4ToUnityXRRect(simd_float4 in_float4);

UnityXRPose EyePositionToUnityXRPose(simd_float3 eye_position);

simd_float4x4 TransformFromUnity(float position[3], float rotation[4]);

std::vector<float> TransformToUnityPosition(simd_float4x4 transform_matrix);

std::vector<float> TransformToUnityRotation(simd_float4x4 transform_matrix);

Eigen::Vector3d CMAccelerationToEigenVector3d(CMAcceleration acceleration);

Eigen::Vector3d CMRotationRateToEigenVector3d(CMRotationRate rotationRate);

Eigen::Vector3d TransformToEigenVector3d(simd_float4x4 transform_matrix);

Eigen::Quaterniond TransformToEigenQuaterniond(simd_float4x4 transform_matrix);

Eigen::Matrix3d MatrixToEigenMatrix3d(simd_float3x3 matrix);

UnityXRVector3 EigenVector3dToUnityXRVector3(Eigen::Vector3d vector3);

UnityXRVector4 EigenQuaterniondToUnityXRVector4(Eigen::Quaterniond quaternion);
