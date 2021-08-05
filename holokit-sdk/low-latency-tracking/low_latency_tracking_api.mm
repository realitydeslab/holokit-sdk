//
//  low_latency_tracking_api.cpp
//  holokit-sdk
//
//  Created by Yuchen on 2021/7/30.
//

#include "low_latency_tracking_api.h"
#include <iostream>
#import <Foundation/Foundation.h>

namespace holokit {

bool LowLatencyTrackingApi::GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) const {
    if (target_timestamp < last_arkit_data_.sensor_timestamp) {
        return false;
    }
    
    double last_time = target_timestamp;
    Eigen::Vector3d p = last_arkit_data_.position;
    for (auto it = accelerometer_data_.begin(); it != accelerometer_data_.end(); ++it) {
        AccelerometerData data = *it;
        p += pow(data.sensor_timestamp - last_time, 2) * data.acceleration / 2 / 9.8;
    }
    Eigen::Quaterniond q = last_arkit_data_.rotation;
    for (auto it = gyro_data_.begin(); it != gyro_data_.end(); ++it) {
        GyroData data = *it;
        q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * data.rotationRate);
    }
    position = p;
    rotation = q;
    return true;
}

Eigen::Quaterniond LowLatencyTrackingApi::ConvertToEigenQuaterniond(Eigen::Vector3d euler) const {
    return Eigen::AngleAxisd(euler[0], ::Eigen::Vector3d::UnitZ()) *
    Eigen::AngleAxisd(euler[1], ::Eigen::Vector3d::UnitY()) *
    Eigen::AngleAxisd(euler[2], ::Eigen::Vector3d::UnitX());
}

void LowLatencyTrackingApi::OnAccelerometerDataUpdated(const AccelerometerData& data) {
    if (!is_active_) return;
    accel_mtx_.lock();
    accelerometer_data_.push_back(data);
    accel_mtx_.unlock();
}

void LowLatencyTrackingApi::OnGyroDataUpdated(const GyroData& data) {
    if (!is_active_) return;
    gyro_mtx_.lock();
    gyro_data_.push_back(data);
    gyro_mtx_.unlock();
}

void LowLatencyTrackingApi::OnARKitDataUpdated(const ARKitData& data) {
    if (!is_active_) return;
    accel_mtx_.lock();
    while (!accelerometer_data_.empty() && data.sensor_timestamp > accelerometer_data_.front().sensor_timestamp) {
        accelerometer_data_.pop_front();
    }
    accel_mtx_.unlock();
    gyro_mtx_.lock();
    while (!gyro_data_.empty() && data.sensor_timestamp > gyro_data_.front().sensor_timestamp) {
        gyro_data_.pop_front();
    }
    gyro_mtx_.unlock();
    
    arkit_mtx_.lock();
    last_arkit_data_ = data;
    arkit_mtx_.unlock();
}

} // namespace holokit
