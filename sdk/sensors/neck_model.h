#ifndef HOLOKIT_SDK_SENSORS_NECK_MODEL_H_
#define HOLOKIT_SDK_SENSORS_NECK_MODEL_H_

#include <array>

namespace holokit {

// The neck model parameters may be exposed as a per-user preference in the
// future, but that's only a marginal improvement, since getting accurate eye
// offsets would require full positional tracking. For now, use hardcoded
// defaults. The values only have an effect when the neck model is enabled.

// Position of the point between the eyes, relative to the neck pivot:
constexpr float kDefaultNeckHorizontalOffset = -0.080f;  // meters in Z
constexpr float kDefaultNeckVerticalOffset = 0.075f;     // meters in Y

// ApplyNeckModel applies a neck model offset based on the rotation of
// |orientation|.
// The value of |factor| is clamped from zero to one.
std::array<float, 3> ApplyNeckModel(const std::array<float, 4>& orientation,
                                    double factor);

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_NECK_MODEL_H_
