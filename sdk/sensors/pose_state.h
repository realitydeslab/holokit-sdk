#ifndef HOLOKIT_SDK_SENSORS_POSE_STATE_H_
#define HOLOKIT_SDK_SENSORS_POSE_STATE_H_

#include "utils/rotation.h"
#include "utils/vector.h"

namespace holokit {

enum {
  kPoseStateFlagInvalid = 1U << 0,
  kPoseStateFlagInitializing = 1U << 1,
  kPoseStateFlagHas6DoF = 1U << 2,
};

// Stores a head pose pose plus derivatives. This can be used for prediction.
struct PoseState {
  // System wall time.
  int64_t timestamp;

  // Rotation from Sensor Space to Start Space.
  Rotation sensor_from_start_rotation;

  // First derivative of the rotation.
  Vector3 sensor_from_start_rotation_velocity;

  // Current gyroscope bias in rad/s.
  Vector3 bias;

  // The position of the headset.
  Vector3 position = Vector3(0, 0, 0);

  // In the same coordinate frame as the position.
  Vector3 velocity = Vector3(0, 0, 0);

  // Flags indicating the status of the pose.
  uint64_t flags = 0U;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_POSE_STATE_H_
