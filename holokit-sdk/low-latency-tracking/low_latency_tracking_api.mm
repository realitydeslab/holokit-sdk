//
//  low_latency_tracking_api.cpp
//  holokit-sdk
//
//  Created by Yuchen on 2021/7/30.
//

#import "low_latency_tracking_api.h"
#import <iostream>
#import "IUnityInterface.h"
#import "core_motion.h"
#import "ar_session_manager.h"
#import "math_helpers.h"
#import "utility.h"
#import <os/log.h>
#import <os/signpost.h>
#import "../holokit_api.h"

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

void LowLatencyTrackingApi::Activate() {
    NSLog(@"[low_latency_tracking]: activate");
    is_active_ = true;
    is_filtering_gyro_ = true;
    is_filtering_acc_ = true;
    
    [[HoloKitCoreMotion sharedCoreMotion] startAccelerometer:^(CMAccelerometerData *accelerometerData) {
        holokit::AccelerometerData data = { accelerometerData.timestamp, CMAccelerationToEigenVector3d(accelerometerData.acceleration) };
        holokit::LowLatencyTrackingApi::GetInstance()->OnAccelerometerDataUpdated(data);
    }];
    
    [[HoloKitCoreMotion sharedCoreMotion] startGyroscope:^void (CMGyroData *gyroData) {
        holokit::GyroData data = { gyroData.timestamp,  CMRotationRateToEigenVector3d(gyroData.rotationRate) };
        holokit::LowLatencyTrackingApi::GetInstance()->OnGyroDataUpdated(data);
        //NSLog(@"[gyro_data]: (%f, %f, %f)", gyroData.rotationRate.x, gyroData.rotationRate.y, gyroData.rotationRate.z);
    }];
};

void LowLatencyTrackingApi::Deactivate() {
    NSLog(@"[low_latency_tracking]: deactivate");
    is_active_ = false;
    
    [[HoloKitCoreMotion sharedCoreMotion] stopAccelerometer];
    [[HoloKitCoreMotion sharedCoreMotion] stopGyroscope];
}

void LowLatencyTrackingApi::InitEKF()
{
//    std::cout << "acc num: " << accelerometer_data_.size() << std::endl;
//    std::cout << "gyro num: " << gyro_data_.size() << std::endl;
    Eigen::Vector3d t = last_arkit_data_.position;
    Eigen::Quaterniond q = last_arkit_data_.rotation;
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
        
        if (target_timestamp < last_arkit_data_.sensor_timestamp || last_arkit_data_.sensor_timestamp == 0) {
            return false;
        }
       arkit_mtx_.lock();
       pose_predictor.setArkitPose(last_arkit_data_);
       arkit_mtx_.unlock();

       accel_mtx_.lock();
       pose_predictor.setAcc(accelerometer_data_);
       accel_mtx_.unlock();

       gyro_mtx_.lock();
       pose_predictor.setGyro(gyro_data_);
       gyro_mtx_.unlock();

       ARSessionManager* arSession = [ARSessionManager sharedARSessionManager];
    double lastFrameTime = arSession.nextVsyncTimestamp - arSession.lastVsyncTimestamp;
    double nextVsyncTime = arSession.nextVsyncTimestamp + 2 * lastFrameTime;
    //double nextVsyncTime = arSession.nextVsyncTimestamp + lastFrameTime;
    if (holokit::HoloKitApi::GetInstance()->GetIsSkippingFrame()) {
        nextVsyncTime += lastFrameTime;
    }
    double lastGyroTime = [[HoloKitCoreMotion sharedCoreMotion] currentGyroData].timestamp;
    //NSLog(@"[low_latency]: prediction time: %f and interval: %f", nextVsyncTime - lastGyroTime, lastFrameTime);
       pose_predictor.getPredcitPose(position, rotation, nextVsyncTime - lastGyroTime);
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

    arkit_mtx_.lock();
    last_arkit_data_ = data;
    arkit_mtx_.unlock();
   AccelerometerData accel;
   accel_mtx_.lock();
   while (!accelerometer_data_.empty() && data.sensor_timestamp > accelerometer_data_.front().sensor_timestamp)
   {
       accel = accelerometer_data_.front();
       accelerometer_data_.pop_front();
   }
   accelerometer_data_.push_front(accel);  //save one frame before arkit data
   accel_mtx_.unlock();
   GyroData gyro;
   gyro_mtx_.lock();
   while (!gyro_data_.empty() && data.sensor_timestamp > gyro_data_.front().sensor_timestamp)
   {
       gyro = gyro_data_.front();
       gyro_data_.pop_front();
   }
   gyro_data_.push_front(gyro); //save one frame before arkit data
   gyro_mtx_.unlock();
}

void LowLatencyTrackingApi::Clear() {
    accel_mtx_.lock();
    accelerometer_data_.clear();
    accel_mtx_.unlock();
    
    gyro_mtx_.lock();
    gyro_data_.clear();
    gyro_mtx_.unlock();
    
    imu_prepare = 0;
    InitEKF();

    // for Interpolation
    cur_acc.acceleration << 0,0,0;
    cur_acc.sensor_timestamp = 0;
    gyro_buf.reserve(2);
    imu_data.acceleration << 0,0,0;
    imu_data.rotationRate << 0,0,0;
    imu_data.sensor_timestamp = 0;
    // arkit_mtx_.lock();
    // last_arkit_data_ = nullptr;
    // arkit_mtx_.unlock();
}

} // namespace holokit

extern "C" {

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_GetLowLatencyTrackingApiActive() {
    return holokit::LowLatencyTrackingApi::GetInstance()->IsActive();
}

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

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_UnityBeginFrameRendering() {
    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    os_signpost_id_t spid = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, spid, "UnityBeginFrameRendering");
    os_signpost_interval_end(log, spid, "UnityBeginFrameRendering");
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_UnityEndFrameRendering() {
    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    os_signpost_id_t spid = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, spid, "UnityEndFrameRendering");
    os_signpost_interval_end(log, spid, "UnityEndFrameRendering");
}

}
