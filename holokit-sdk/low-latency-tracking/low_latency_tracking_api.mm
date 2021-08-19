//
//  low_latency_tracking_api.cpp
//  holokit-sdk
//
//  Created by Yuchen on 2021/7/30.
//

#import "low_latency_tracking_api.h"
#import <iostream>
#import <Foundation/Foundation.h>
#import "IUnityInterface.h"

namespace holokit {

std::unique_ptr<LowLatencyTrackingApi> LowLatencyTrackingApi::low_latency_tracking_api_;

std::unique_ptr<LowLatencyTrackingApi>& LowLatencyTrackingApi::GetInstance() {
    if (!low_latency_tracking_api_) {
        low_latency_tracking_api_.reset(new holokit::LowLatencyTrackingApi);
    }
    return low_latency_tracking_api_;
}

bool LowLatencyTrackingApi::GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) const {
    if (!is_active_) return false;
    
    if (target_timestamp < last_arkit_data_.sensor_timestamp) {
        return false;
    }
    
    double last_time = target_timestamp;
    IMUFilter imu_filter;
    
    Eigen::Quaterniond q = last_arkit_data_.rotation;
    // Convert from IMU space to camera space
    Eigen::Matrix3d R_I2C;
    R_I2C << 0, -1, 0, 1, 0, 0, 0, 0, 1;
    
    std::cout << "[time lag arkit]: " << target_timestamp - last_arkit_data_.sensor_timestamp << std::endl;
    std::cout << "[time lag]: " << target_timestamp - gyro_data_.back().sensor_timestamp << std::endl;
    for (auto it = gyro_data_.begin(); it != gyro_data_.end(); ++it) {
        GyroData data = *it;
        
        
        
        if (is_filtering_gyro_) {
            Vector3d filtered_gyro;
            imu_filter.get_filted_gyro(data.rotationRate, filtered_gyro);
            std::cout << std::endl;
            std::cout << "[before filtered]: (" << data.rotationRate(0) << ", " << data.rotationRate(1) << ", " << data.rotationRate(2) << ")" << std::endl;
            std::cout << "[after filtered]: (" << filtered_gyro(0) << ", " << filtered_gyro(1) << ", " << filtered_gyro(2) << ")" << std::endl;
            q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * filtered_gyro);
        } else {
            q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * data.rotationRate);
        }
    }
    
    Eigen::Vector3d p = last_arkit_data_.position;
//    for (auto it = accelerometer_data_.begin(); it != accelerometer_data_.end(); ++it) {
//        AccelerometerData data = *it;
//        Vector3d filtered_acc;
//        imu_filter.get_filted_acc(data.acceleration, filtered_acc);
//        p += pow(data.sensor_timestamp - last_time, 2) * filtered_acc / 2 * 9.8;
//    }
    
    position = p;
    rotation = q;
    return true;
}

Eigen::Quaterniond LowLatencyTrackingApi::ConvertToEigenQuaterniond(Eigen::Vector3d euler) const {
    return Eigen::AngleAxisd(euler[0], ::Eigen::Vector3d::UnitX()) *
    Eigen::AngleAxisd(euler[1], ::Eigen::Vector3d::UnitY()) *
    Eigen::AngleAxisd(euler[2], ::Eigen::Vector3d::UnitZ());
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

void LowLatencyTrackingApi::Clear() {
    accel_mtx_.lock();
    accelerometer_data_.clear();
    accel_mtx_.unlock();
    
    gyro_mtx_.lock();
    gyro_data_.clear();
    gyro_mtx_.unlock();
    
//    arkit_mtx_.lock();
//    last_arkit_data_ = nullptr;
//    arkit_mtx_.unlock();
}

} // namespace holokit

extern "C" {

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetLowLatencyTrackingApiActive(bool value) {
    if (value) {
        holokit::LowLatencyTrackingApi::GetInstance()->Activate();
    } else {
        holokit::LowLatencyTrackingApi::GetInstance()->Deactivate();
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetIsFilteringGyro(bool value) {
    holokit::LowLatencyTrackingApi::GetInstance()->SetIsFilteringGyro(value);
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetIsFilteringAcc(bool value) {
    holokit::LowLatencyTrackingApi::GetInstance()->SetIsFilteringAcc(value);
}

}
