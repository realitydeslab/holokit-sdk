//
//  low_latency_tracking_api.cpp
//  holokit-sdk
//
//  Created by Yuchen on 2021/7/30.
//

#import "LowLatencyTracking.h"
#import <iostream>
#import <os/log.h>
#import <os/signpost.h>

//#import "core_motion.h"
//#import "math_helpers.h"
//#import "utility.h"


namespace holokit {

std::unique_ptr<LowLatencyTracking> LowLatencyTracking::low_latency_tracking_;

std::unique_ptr<LowLatencyTracking>& LowLatencyTracking::GetInstance() {
    if (!low_latency_tracking_) {
        low_latency_tracking_.reset(new holokit::LowLatencyTracking);
    }
    return low_latency_tracking_;
}

LowLatencyTracking::LowLatencyTracking()
{
    // for Interpolation
//    cur_acc.acceleration << 0,0,0;
//    cur_acc.sensor_timestamp = 0;
//    gyro_buf.reserve(2);
//    imu_data.acceleration << 0,0,0;
//    imu_data.rotationRate << 0,0,0;
//    imu_data.sensor_timestamp = 0;

    //bias
//    gyro_bias << -0.000304832857143, -0.0124482685714, -0.00709643285714;
}

void LowLatencyTracking::Activate() {
    NSLog(@"[low_latency_tracking]: activate");
    is_active_ = true;
    is_filtering_gyro_ = true;
    is_filtering_acc_ = true;
    
    [[HoloKitCoreMotion sharedCoreMotion] startAccelerometer:^(CMAccelerometerData *accelerometerData) {
        AccelerometerData data = { accelerometerData.timestamp, Eigen::Vector3d(accelerometerData.acceleration.x, accelerometerData.acceleration.y, accelerometerData.acceleration.z)};
        LowLatencyTracking::GetInstance()->OnAccelerometerDataUpdated(data);
    }];
    
    [[HoloKitCoreMotion sharedCoreMotion] startGyroscope:^void (CMGyroData *gyroData) {
        GyroData data = { gyroData.timestamp,  CMRotationRateToEigenVector3d(gyroData.rotationRate) };
        LowLatencyTracking::GetInstance()->OnGyroDataUpdated(data);
    }];
};

void LowLatencyTracking::Deactivate() {
    NSLog(@"[low_latency_tracking]: deactivate");
    is_active_ = false;
    
    [[HoloKitCoreMotion sharedCoreMotion] stopAccelerometer];
    [[HoloKitCoreMotion sharedCoreMotion] stopGyroscope];
}

void LowLatencyTracking::InitEKF()
{
//    std::cout << "acc num: " << accelerometer_data_.size() << std::endl;
//    std::cout << "gyro num: " << gyro_data_.size() << std::endl;
    Eigen::Vector3d t = last_arkit_data_.position;
    Eigen::Quaterniond q = last_arkit_data_.rotation;
    Eigen::Vector3d acc = imu_data.acceleration;
    Eigen::Vector3d gyro = imu_data.rotationRate + gyro_bias;
    
    Eigen::Matrix3d R_ci;  //from c to i
    R_ci << 0,-1,0,1,0,0,0,0,1;
    Eigen::Vector3d T_ci;  //from c to i
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

bool LowLatencyTracking::UpdateWithMeasurement(const MeasurementData& data) {
    
    
}

bool LowLatencyTracking::GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) {
    if (!is_active_) {
        return false;
    }
    
    auto last_state = ekf_state_queue_.crbegin();
    if (last_state == ekf_state_queue_.crend()) {
        return false;
    }
    
    if (target_timestamp < last_state->timestamp) {
        return false;
    }
    
    auto state = PredictEKFState(*last_state, target_timestamp);
    position = state.GetPosition();
    rotation = state.GetRotation();
    
    return true;
}

void LowLatencyTracking::UpdateWithMeasurement(const MeasurementData& data)
{
    if (!is_active_) {
        return;
    }
    
    auto last_state = ekf_state_queue_.crbegin();
    if (last_state == ekf_state_queue_.crend()) {
        return false;
    }
    
    if (data.sensor_timestamp < last_state->timestamp) {
        return false;
    }

   
}

void LowLatencyTracking::OnARKitPoseDataUpdated(const ARKitData& data) {
    
    while (ekf_state_queue_.crbegin() != ekf_state_queue_.crend() &&
           data.sensor_timestamp <= last_state->timestamp) {
        ekf_state_queue_.pop_back();
    }
    
    auto new_state = PredictEKFState(*last_state, data.sensor_timestamp);
    measurement_data_.push_back(data);
    UpdateWithAccelerometer(data);
    UpdateWithARKitPose(data);
    
    while (measurement_data_.begin() != measurement_data_.end() ) {
        ekf_state_queue_.pop_back();
        UpdateWithMeasurement(data);
    }
    
}
void LowLatencyTracking::OnAccelerometerDataUpdated(const AccelerometerData& data)
{
    if (!is_active_) {
        return;
    }
    
    auto last_state = ekf_state_queue_.crbegin();
    if (last_state == ekf_state_queue_.crend()) {
        return false;
    }
    
    if (data.sensor_timestamp < last_state->timestamp) {
        return false;
    }

    PredictEKFState(*last_state, data.sensor_timestamp)
    UpdateWithAccelerometer(data);
    measurement_data_.push_back(data);
}

void LowLatencyTracking::OnGyroscopeDataUpdated(const GyroscopeData& data) {
    UpdateGyroscope(data);
    gyroscopeData.push_back(data);
}


void LowLatencyTracking::OnARKitPoseDataUpdated(const ARKitData& data) {
    if (!is_active_) return;

    arkit_mtx_.lock();
    last_arkit_data_ = data;
    arkit_mtx_.unlock();

#ifdef NO_EKF
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
#else
//    std::cout << "first frame arkit: " << last_arkit_data_.position;

    if(ekf_init_flag)
    {
        pose_ekf.measurementCallback(data.position, data.rotation, data.sensor_timestamp);
    }

    if(imu_good_flag && !ekf_init_flag)
    {
        InitEKF();
        ekf_init_flag = true;
    }
#endif
}

void LowLatencyTracking::Clear() {
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
UnityHoloKit_GetLowLatencyTrackingActive() {
    return holokit::LowLatencyTracking::GetInstance()->IsActive();
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetLowLatencyTrackingActive(bool value) {
    if (value) {
        holokit::LowLatencyTracking::GetInstance()->Activate();
    } else {
        holokit::LowLatencyTracking::GetInstance()->Deactivate();
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetIsFilteringGyro(bool value) {
    holokit::LowLatencyTracking::GetInstance()->SetIsFilteringGyro(value);
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetIsFilteringAcc(bool value) {
    holokit::LowLatencyTracking::GetInstance()->SetIsFilteringAcc(value);
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_UnityBeginFrameRendering() {
    os_log_t log = os_log_create("com.holoi.holokit.holokit-sdk", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    os_signpost_id_t spid = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, spid, "UnityBeginFrameRendering");
    os_signpost_interval_end(log, spid, "UnityBeginFrameRendering");
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_UnityEndFrameRendering() {
    os_log_t log = os_log_create("com.holoi.holokit.holokit-sdk", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    os_signpost_id_t spid = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, spid, "UnityEndFrameRendering");
    os_signpost_interval_end(log, spid, "UnityEndFrameRendering");
}

}
