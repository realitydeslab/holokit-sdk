//
//  low_latency_tracking_api.h
//  holokit
//
//  Created by Yuchen on 2021/7/30.
//

#ifndef low_latency_tracking_api_h
#define low_latency_tracking_api_h

#include <simd/simd.h>
#include "Eigen/Geometry"
#include <deque>
#include <mutex>
#include <memory>
#include "imu_process.h"

namespace holokit {

struct AccelerometerData {
    double sensor_timestamp;
    Eigen::Vector3d acceleration;
};

struct GyroData {
    double sensor_timestamp;
    Eigen::Vector3d rotationRate;
};

struct ARKitData {
    double sensor_timestamp;
    Eigen::Vector3d position;
    Eigen::Quaterniond rotation;
    Eigen::Matrix3d intrinsics;
};

class LowLatencyTrackingApi {
    
public:
    LowLatencyTrackingApi() {};
    
    bool GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) const;
    
    void OnAccelerometerDataUpdated(const AccelerometerData& data);
    
    void OnGyroDataUpdated(const GyroData& data);
    
    void OnARKitDataUpdated(const ARKitData& data);
    
    static std::unique_ptr<LowLatencyTrackingApi>& GetInstance();
    
    void Activate() { is_active_ = true; is_filtering_gyro_ = true; is_filtering_acc_ = true; };
    
    void Deactivate() { is_active_ = false; }
    
    bool IsActive() { return is_active_; }
    
    void Clear();
    
    void SetIsFilteringGyro(bool value) { is_filtering_gyro_ = value; }
    
    void SetIsFilteringAcc(bool value) { is_filtering_acc_ = value; }
    
private:
    Eigen::Quaterniond ConvertToEigenQuaterniond(Eigen::Vector3d euler) const;
    
private:
    static std::unique_ptr<LowLatencyTrackingApi> low_latency_tracking_api_;
    
    std::deque<AccelerometerData> accelerometer_data_;
    
    std::deque<GyroData> gyro_data_;
    
    ARKitData last_arkit_data_;
    
    std::mutex accel_mtx_;
    
    std::mutex gyro_mtx_;
    
    std::mutex arkit_mtx_;
    
    bool is_active_ = false;
    
    bool is_filtering_gyro_ = true;
    
    bool is_filtering_acc_ = true;
}; // class LowLatencyTrackingApi

//std::unique_ptr<LowLatencyTrackingApi>& LowLatencyTrackingApi::GetInstance();

} // namespace holokit

#endif /* low_latency_tracking_api_h */
