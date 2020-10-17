
#ifndef HOLOKIT_SDK_HEAD_TRACKER_H_
#define HOLOKIT_SDK_HEAD_TRACKER_H_

#include <array>
#include <memory>
#include <mutex>  // NOLINT

#include "sensors/accelerometer_data.h"
#include "sensors/gyroscope_data.h"
#include "sensors/sensor_event_producer.h"
#include "sensors/sensor_fusion_ekf.h"
#include "utils/rotation.h"

namespace holokit {

// HeadTracker encapsulates pose tracking by connecting sensors
// to SensorFusion.
// This pose tracker reports poses in display space.
class HeadTracker {
 public:
  HeadTracker();
  virtual ~HeadTracker();

  // Pauses tracking and sensors.
  void Pause();

  // Resumes tracking ans sensors.
  void Resume();

  // Gets the predicted pose for a given timestamp.
  // TODO(b/135488467): Support different display to sensor orientations.
  void GetPose(int64_t timestamp_ns, std::array<float, 3>& out_position,
               std::array<float, 4>& out_orientation) const;

 private:
  // Function called when receiving AccelerometerData.
  //
  // @param event sensor event.
  void OnAccelerometerData(const AccelerometerData& event);

  // Function called when receiving GyroscopeData.
  //
  // @param event sensor event.
  void OnGyroscopeData(const GyroscopeData& event);

  // Registers this as a listener for data from the accel and gyro sensors. This
  // is useful for informing the sensors that they may need to start polling for
  // data.
  void RegisterCallbacks();
  // Unregisters this as a listener for data from the accel and gyro sensors.
  // This is useful for informing the sensors that they may be able to stop
  // polling for data.
  void UnregisterCallbacks();

  Rotation GetDefaultOrientation() const;

  std::atomic<bool> is_tracking_;
  // Sensor Fusion object that stores the internal state of the filter.
  std::unique_ptr<SensorFusionEkf> sensor_fusion_;
  // Latest gyroscope data.
  GyroscopeData latest_gyroscope_data_;

  // Event providers supplying AccelerometerData and GyroscopeData to the
  // detector.
  std::shared_ptr<SensorEventProducer<AccelerometerData>> accel_sensor_;
  std::shared_ptr<SensorEventProducer<GyroscopeData>> gyro_sensor_;

  // Callback functions registered to the input SingleTypeEventProducer.
  std::function<void(AccelerometerData)> on_accel_callback_;
  std::function<void(GyroscopeData)> on_gyro_callback_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_HEAD_TRACKER_H_
