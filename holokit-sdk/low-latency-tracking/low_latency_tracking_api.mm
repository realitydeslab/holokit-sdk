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

LowLatencyTrackingApi::LowLatencyTrackingApi()
{
    // for Interpolation
    cur_acc.acceleration << 0,0,0;
    cur_acc.sensor_timestamp = 0;
    gyro_buf.reserve(2);
    imu_data.acceleration << 0,0,0;
    imu_data.rotationRate << 0,0,0;
    imu_data.sensor_timestamp = 0;

    //bias
    gyro_bias << -0.000304832857143, -0.0124482685714, -0.00709643285714;
}

void LowLatencyTrackingApi::InitEKF()
{
    NSLog(@"arkit data timestamp: %f", last_arkit_data_.sensor_timestamp);
    //NSLog(@"acc timestamp: %f", accelerometer_data_.front().sensor_timestamp);
    //NSLog(@"gyro timestamp: %f", gyro_data_.front().sensor_timestamp);
    
    //std::cout << "acc num: " << accelerometer_data_.size() << std::endl;
    //std::cout << "gyro num: " << gyro_data_.size() << std::endl;
//    Eigen::Vector3d t = last_arkit_data_.position;
//    Eigen::Quaterniond q = last_arkit_data_.rotation;
    Eigen::Vector3d t(0,0,0);
    Eigen::Quaterniond q(1,0,0,0);
    Eigen::Vector3d acc = imu_data.acceleration;
    Eigen::Vector3d gyro = imu_data.rotationRate + gyro_bias;
    
    Eigen::Matrix3d R_ci;
    R_ci << 0,-1,0,1,0,0,0,0,1;
    Eigen::Vector3d T_ci;
    T_ci << 0,0.65,0;
    
    Vector3d b_w0(0,0,0);
    Vector3d b_a0(0,0,0);
    Matrix<double, N_STATE, N_STATE> P0 = Matrix<double, N_STATE, N_STATE>::Zero();
    Vector3d w0 = gyro;
    Vector3d a0 = acc;
    double L = 1;
    Quaterniond q_wv(1,0,0,0);   // from w to v
    Quaterniond q_ci = Eigen::Quaterniond(R_ci);  //from c to i
    Vector3d p_ci = T_ci;
    Vector3d g(0,9.81,0);
    Vector3d p0 = -q.toRotationMatrix() * R_ci.transpose() * T_ci +  t;   //from i to world
    Vector3d v0(0,0,0);
    Quaterniond q0 = q * q_ci.conjugate();
    //cout << " "<<q0.w() << " "<<q0.x() << " "<<q0.y() << " "<<q0.z() << endl;
    double time0 = imu_data.sensor_timestamp;
    
    pose_ekf.initialize(p0, v0, q0, b_w0, b_a0, L, q_wv, P0, w0, a0, g, q_ci, p_ci, time0);
}

bool LowLatencyTrackingApi::GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) {
    if (!is_active_) return false;
    
    if (target_timestamp < last_arkit_data_.sensor_timestamp) {
        return false;
    }
    
//    double last_time = target_timestamp;
//    IMUFilter imu_filter;
//
//    Eigen::Quaterniond q = last_arkit_data_.rotation;
//    // Convert from IMU space to camera space
//    Eigen::Matrix3d R_I2C;
//    R_I2C << 0, -1, 0, 1, 0, 0, 0, 0, 1;
//
//    //std::cout << "[time lag arkit]: " << target_timestamp - last_arkit_data_.sensor_timestamp << std::endl;
//    //std::cout << "[time lag]: " << target_timestamp - gyro_data_.back().sensor_timestamp << std::endl;
//    for (auto it = gyro_data_.begin(); it != gyro_data_.end(); ++it) {
//        GyroData data = *it;
//
//        if (is_filtering_gyro_) {
//            Vector3d filtered_gyro;
//            imu_filter.get_filted_gyro(data.rotationRate, filtered_gyro);
//            //std::cout << std::endl;
//            //std::cout << "[before filtered]: (" << data.rotationRate(0) << ", " << data.rotationRate(1) << ", " << data.rotationRate(2) << ")" << std::endl;
//            //std::cout << "[after filtered]: (" << filtered_gyro(0) << ", " << filtered_gyro(1) << ", " << filtered_gyro(2) << ")" << std::endl;
//            q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * filtered_gyro);
//        } else {
//            q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * data.rotationRate);
//        }
//    }
//
//    Eigen::Vector3d p = last_arkit_data_.position;
////    for (auto it = accelerometer_data_.begin(); it != accelerometer_data_.end(); ++it) {
////        AccelerometerData data = *it;
////        Vector3d filtered_acc;
////        imu_filter.get_filted_acc(data.acceleration, filtered_acc);
////        p += pow(data.sensor_timestamp - last_time, 2) * filtered_acc / 2 * 9.8;
////    }
//
//    position = p;
//    rotation = q;
    
    pose_ekf.getRealPose(position, rotation);
    
    return true;
}

Eigen::Quaterniond LowLatencyTrackingApi::ConvertToEigenQuaterniond(Eigen::Vector3d euler) const {
    return Eigen::AngleAxisd(euler[0], ::Eigen::Vector3d::UnitX()) *
    Eigen::AngleAxisd(euler[1], ::Eigen::Vector3d::UnitY()) *
    Eigen::AngleAxisd(euler[2], ::Eigen::Vector3d::UnitZ());
}

void LowLatencyTrackingApi::OnAccelerometerDataUpdated(const AccelerometerData& data) {
    if (!is_active_) return;
//    accel_mtx_.lock();
    
//    accelerometer_data_.push_back(data);
//    accel_mtx_.unlock();
    cur_acc.acceleration = data.acceleration * 9.81f;
    cur_acc.sensor_timestamp = data.sensor_timestamp;
    if(imu_prepare<10)
     {
         imu_prepare++;
     }
}

void LowLatencyTrackingApi::OnGyroDataUpdated(const GyroData& data) {
    if (!is_active_) return;
//    gyro_mtx_.lock();
    
//    gyro_data_.push_back(data);
//    gyro_mtx_.unlock();
    if(data.sensor_timestamp <= 0) return;
    if(imu_prepare < 10) return;

    if(gyro_buf.size() == 0)
     {
         gyro_buf.push_back(data);
         gyro_buf.push_back(data);
         return;
     }
     else
     {
         gyro_buf[0] = gyro_buf[1];
         gyro_buf[1] = data;
     }
     //interpolation
     if(cur_acc.sensor_timestamp >= gyro_buf[0].sensor_timestamp && cur_acc.sensor_timestamp < gyro_buf[1].sensor_timestamp)
     {
         imu_data.sensor_timestamp = cur_acc.sensor_timestamp;
         imu_data.acceleration = cur_acc.acceleration;
         imu_data.rotationRate = gyro_buf[0].rotationRate + (cur_acc.sensor_timestamp - gyro_buf[0].sensor_timestamp)*(gyro_buf[1].rotationRate - gyro_buf[0].rotationRate)/(gyro_buf[1].sensor_timestamp - gyro_buf[0].sensor_timestamp);
         imu_good_flag = true;
         //printf("imu gyro update %lf %lf %lf\n", gyro_buf[0].header, imu_msg->header, gyro_buf[1].header);
         //printf("imu inte update %lf %lf %lf %lf\n", imu_msg->header, gyro_buf[0].gyr.x(), imu_msg->gyr.x(), gyro_buf[1].gyr.x());
     }
     else
     {
         printf("imu error %lf %lf %lf\n", gyro_buf[0].sensor_timestamp, cur_acc.sensor_timestamp, gyro_buf[1].sensor_timestamp);
         return;
     }

    if(ekf_init_flag)
    {
        pose_ekf.imuCallback(imu_data.acceleration, imu_data.rotationRate + gyro_bias, imu_data.sensor_timestamp);
    }
    
    if(imu_good_flag && !ekf_init_flag)
    {
        InitEKF();
        ekf_init_flag = true;
    }
}

void LowLatencyTrackingApi::OnARKitDataUpdated(const ARKitData& data) {
    if (!is_active_) return;
//    accel_mtx_.lock();
//    while (!accelerometer_data_.empty() && data.sensor_timestamp > accelerometer_data_.front().sensor_timestamp) {
//        accelerometer_data_.pop_front();
//    }
//    accel_mtx_.unlock();
//    gyro_mtx_.lock();
//    while (!gyro_data_.empty() && data.sensor_timestamp > gyro_data_.front().sensor_timestamp) {
//        gyro_data_.pop_front();
//    }
//    gyro_mtx_.unlock();

    
    arkit_mtx_.lock();
    last_arkit_data_ = data;
    arkit_mtx_.unlock();
    std::cout << "first frame arkit: " << last_arkit_data_.position;

    if(ekf_init_flag)
    {
        pose_ekf.measurementCallback(last_arkit_data_.position, last_arkit_data_.rotation, last_arkit_data_.sensor_timestamp);
    }


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
