#import "sensors/device_accelerometer_sensor.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import <sys/types.h>
#import <thread>

#import "sensors/accelerometer_data.h"
#import "sensors/ios/sensor_helper.h"

namespace holokit {
static const int64_t kNsecPerSec = 1000000000;

// This struct holds ios specific sensor information.
struct DeviceAccelerometerSensor::SensorInfo {
  SensorInfo() {}
};

DeviceAccelerometerSensor::DeviceAccelerometerSensor() : sensor_info_(new SensorInfo()) {}

DeviceAccelerometerSensor::~DeviceAccelerometerSensor() {}

void DeviceAccelerometerSensor::PollForSensorData(int timeout_ms,
                                                  std::vector<AccelerometerData>* results) const {
  results->clear();
  @autoreleasepool {
    HoloKitSensorHelper* helper = [HoloKitSensorHelper sharedSensorHelper];
    const float x = static_cast<float>(-9.8f * helper.accelerometerData.acceleration.x);
    const float y = static_cast<float>(-9.8f * helper.accelerometerData.acceleration.y);
    const float z = static_cast<float>(-9.8f * helper.accelerometerData.acceleration.z);

    AccelerometerData sample;
    uint64_t nstime = helper.accelerometerData.timestamp * kNsecPerSec;
    sample.sensor_timestamp_ns = nstime;
    sample.system_timestamp = nstime;
    sample.data.Set(x, y, z);
    results->push_back(sample);
  }
}

bool DeviceAccelerometerSensor::Start() {
  return [[HoloKitSensorHelper sharedSensorHelper] isAccelerometerAvailable];
}

void DeviceAccelerometerSensor::Stop() {
  // This should never be called on iOS.
}

}  // namespace holokit
