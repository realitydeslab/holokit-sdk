#import "sensors/device_gyroscope_sensor.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import <sys/types.h>
#import <thread>

#import "sensors/gyroscope_data.h"
#import "sensors/ios/sensor_helper.h"
#import "utils/vector.h"

namespace holokit {
static const int64_t kNsecPerSec = 1000000000;

// This struct holds gyroscope specific sensor information.
struct DeviceGyroscopeSensor::SensorInfo {
  // The initial System gyro bias values. *used for testing*
  static Vector3 initial_system_gyro_bias;
};

// Defines the static variable.
Vector3 DeviceGyroscopeSensor::SensorInfo::initial_system_gyro_bias = Vector3::Zero();

DeviceGyroscopeSensor::DeviceGyroscopeSensor() : sensor_info_(new SensorInfo()) {}

DeviceGyroscopeSensor::~DeviceGyroscopeSensor() {}

void DeviceGyroscopeSensor::PollForSensorData(int timeout_ms,
                                              std::vector<GyroscopeData>* results) const {
  results->clear();
  @autoreleasepool {
    HoloKitSensorHelper* helper = [HoloKitSensorHelper sharedSensorHelper];
    const float x = static_cast<float>(helper.deviceMotion.rotationRate.x);
    const float y = static_cast<float>(helper.deviceMotion.rotationRate.y);
    const float z = static_cast<float>(helper.deviceMotion.rotationRate.z);

    GyroscopeData sample;
    uint64_t nstime = helper.deviceMotion.timestamp * kNsecPerSec;
    sample.sensor_timestamp_ns = nstime;
    sample.system_timestamp = nstime;
    sample.data.Set(x, y, z);
    results->push_back(sample);
  }
}

bool DeviceGyroscopeSensor::Start() {
  return [[HoloKitSensorHelper sharedSensorHelper] isGyroAvailable];
}

void DeviceGyroscopeSensor::Stop() {
  // This should never be called on iOS.
}

// This function returns gyroscope initial system bias
Vector3 DeviceGyroscopeSensor::GetInitialSystemBias() {
  return SensorInfo::initial_system_gyro_bias;
}

}  // namespace holokit
