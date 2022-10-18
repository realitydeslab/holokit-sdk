//
//  LowLatencyTracking.hpp
//  holokit-sdk
//
//  Created by Botao Hu on 10/15/22.
//

#ifndef LowLatencyTracking_h
#define LowLatencyTracking_h

#include <simd/simd.h>
#include <deque>
#include <mutex>
#include <memory>
#include <Eigen/Eigen>
#include <sophus/se3.hpp>

namespace holokit {

struct AccelerometerData {
    double sensor_timestamp;
    Eigen::Vector3d acceleration;
};

struct MeasurementData {
    double sensor_timestamp;
    union
    {
        Eigen::Vector3d acceleration;
        int i;
        double d;
    };
    Eigen::Vector3d rotationRate;
};

struct CoreMotionData {
    double sensor_timestamp;
    Eigen::Vector3d acceleration;
    Eigen::Vector3d rotationRate;
};

struct ARKitPoseData {
    double sensor_timestamp;
    Eigen::Vector3d position;
    Eigen::Quaterniond rotation;
    Eigen::Matrix3d intrinsics;
};

struct EKFState {
    double timestamp;
    
    
    Sophus::SE3d::Tangent GetRotationTagent();
    Sophus::SE3d::Tangent GetAngluarRateTagent();
    Eigen::Vector3d GetPosition();
    Eigen::Vector3d GetVelocity();
    Eigen::Vector3d GetGyroBias();
    Eigen::Vector3d GetAccelBias();

    Eigen::Vector<double, 21> X;
    Eigen::Matrix<double, 21, 21> P;
};


class LowLatencyTracking {
    
public:
    LowLatencyTracking();
    
    bool GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation);
    
    void OnAccelerometerDataUpdated(const AccelerometerData& accelerometerData);
    
    void OnGyroscopeDataUpdated(double record_timestamp, const GyroscopeData& data);
    
    void OnARKitPoseDataUpdated(double record_timestamp, const ARKitPoseData& data);
    
    void OnMeasurement(const MeasurementData& data);
    
    static std::unique_ptr<LowLatencyTracking>& GetInstance();
    
    void InitEKF();
    
    void Activate();
    
    void Deactivate();
    
    bool IsActive() { return is_active_; }
    
    void Clear();
    
    void SetIsFilteringGyro(bool value) { is_filtering_gyro_ = value; }
    
    void SetIsFilteringAcc(bool value) { is_filtering_acc_ = value; }
    
private:
    Eigen::Quaterniond ConvertToEigenQuaterniond(Eigen::Vector3d euler) const;
    
private:
    static std::unique_ptr<LowLatencyTracking> low_latency_tracking_;

    const double k_accelerometer_random_walking_noise = 0.1;
    const double k_gyroscope_walking_noise = 0.1;
    const double k_accelerometer_measurement_noise = 0.1;
    const double k_gyroscope_measurement_noise = 0.1;
    const double k_arkit_pose_measurement_noise = 0.1;
    const double k_process_position_noise = 0.1;
    const double k_process_velocity_noise = 0.1;
    const double k_process_log_rotation_noise = 0.1;
    const double k_process_log_angle_rate_noise = 0.1;
    const double k_process_log_gyroscope_bias_noise = 0.1;
    const double k_process_log_accelerometer_bias_noise = 0.1;

    static std::unique_ptr<LowLatencyTracking> low_latency_tracking;
    
    std::deque<MeasurementData> measurement_buffer_;
    
    std::deque<EKFState> state_buffer_;
            
    std::mutex accel_mtx_;
    
    std::mutex gyro_mtx_;
    
    std::mutex arkit_mtx_;
    
    bool is_active_ = false;
    
    bool is_filtering_gyro_ = true;
    
    bool is_filtering_acc_ = true;
    
    bool ekf_init_flag = false;
    bool imu_good_flag = false;
    
}; // class LowLatencyTrackingApi

}

#endif /* LowLatencyTracking_h */
