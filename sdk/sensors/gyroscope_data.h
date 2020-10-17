#ifndef HOLOKIT_SDK_SENSORS_GYROSCOPE_DATA_H_
#define HOLOKIT_SDK_SENSORS_GYROSCOPE_DATA_H_

#include "utils/vector.h"

namespace holokit {

struct GyroscopeData {
  // System wall time.
  uint64_t system_timestamp;

  // Sensor clock time in nanoseconds.
  uint64_t sensor_timestamp_ns;

  // Rate of rotation around the x,y,z axes in rad/s. This follows android
  // specification
  // (https://developer.android.com/guide/topics/sensors/sensors_overview.html#sensors-coords).
  Vector3 data;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_GYROSCOPE_DATA_H_
