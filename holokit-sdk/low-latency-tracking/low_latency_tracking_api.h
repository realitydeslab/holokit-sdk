//
//  low_latency_tracking_api.h
//  holokit
//
//  Created by Yuchen on 2021/7/30.
//
#pragma once
#include <simd/simd.h>
#include "Eigen/Geometry"
#include "ceres/internal/eigen.h"
#include <deque>
#include <mutex>
#include <memory>

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
    
    void Activate() { is_active_ = true; };
    
    void Deactivate() { is_active_ = false; }
    
    bool IsActive() { return is_active_; }
    
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
}; // class LowLatencyTrackingApi

std::unique_ptr<LowLatencyTrackingApi> LowLatencyTrackingApi::low_latency_tracking_api_;

std::unique_ptr<LowLatencyTrackingApi>& LowLatencyTrackingApi::GetInstance() {
    if (!low_latency_tracking_api_) {
        low_latency_tracking_api_.reset(new holokit::LowLatencyTrackingApi);
    }
    return low_latency_tracking_api_;
}


} // namespace holokit
