#include "sensors/neck_model.h"

#include <algorithm>

#include "utils/rotation.h"
#include "utils/vector.h"

namespace holokit {

std::array<float, 3> ApplyNeckModel(const std::array<float, 4>& orientation,
                                    double factor) {
  // Clamp factor 0-1.
  const double local_neck_model_factor = std::min(std::max(factor, 0.0), 1.0);
  Rotation rotation = Rotation::FromQuaternion(
      Vector4(orientation[0], orientation[1], orientation[2], orientation[3]));
  Vector3 position;

  // To apply the neck model, first translate the head pose to the new
  // center of eyes, then rotate around the origin (the original head pos).
  const Vector3 offset =
      // Rotate eyes around neck pivot point.
      rotation * Vector3(0.0f, kDefaultNeckVerticalOffset,
                         kDefaultNeckHorizontalOffset) -
      // Measure new position relative to original center of head, because
      // applying a neck model should not elevate the camera.
      Vector3(0.0f, kDefaultNeckVerticalOffset, 0.0f);

  const Vector3 out_position = offset * local_neck_model_factor;
  return {static_cast<float>(out_position[0]),
          static_cast<float>(out_position[1]),
          static_cast<float>(out_position[2])};
}

}  // namespace holokit
