#ifndef THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_MATH_TOOLS_H_
#define THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_MATH_TOOLS_H_

#include <array>
#include <cmath>

#include "UnityXRTypes.h"

namespace holokit {
namespace unity {

/// @brief Creates a UnityXRPose from a HoloKit rotation.
/// @param rotation A HoloKit rotation quaternion expressed as [x, y, z, w].
/// @returns A UnityXRPose from HoloKit @p rotation.
UnityXRPose HoloKitRotationToUnityPose(const std::array<float, 4>& rotation);

/// @brief Creates a UnityXRPose from a HoloKit transformation matrix.
/// @param transform A 4x4 float transformation matrix.
/// @returns A UnityXRPose from HoloKit @p transform.
UnityXRPose HoloKitTransformToUnityPose(
    const std::array<float, 16>& transform);

}  // namespace unity
}  // namespace holokit

#endif  // THIRD_PARTY_HOLOKIT_OSS_UNITY_PLUGIN_SOURCE_MATH_TOOLS_H_
