#ifndef HOLOKIT_SDK_SENSORS_ACCELEROMETER_DATA_H_
#define HOLOKIT_SDK_SENSORS_ACCELEROMETER_DATA_H_

#include "utils/vector.h"

namespace holokit {

struct AccelerometerData {
  // System wall time.
  uint64_t system_timestamp;

  // Sensor clock time in nanoseconds.
  uint64_t sensor_timestamp_ns;

  // Acceleration force along the x,y,z axes in m/s^2. This follows android
  // specification
  // (https://developer.android.com/guide/topics/sensors/sensors_overview.html#sensors-coords).
  Vector3 data;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_ACCELEROMETER_DATA_H_
