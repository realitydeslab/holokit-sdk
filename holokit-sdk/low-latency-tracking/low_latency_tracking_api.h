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
#include "pose_ekf.h"

#define NO_EKF
#define GYRO_INTEGRATE
#define DELAY_TIME 0.01666
//#define PREDICT

namespace holokit {

struct AccelerometerData {
    double sensor_timestamp;
    Eigen::Vector3d acceleration;
};

struct GyroData {
    double sensor_timestamp;
    Eigen::Vector3d rotationRate;
};

struct IMUData {
    double sensor_timestamp;
    Eigen::Vector3d acceleration;
    Eigen::Vector3d rotationRate;
};

struct ARKitData {
    double sensor_timestamp;
    Eigen::Vector3d position;
    Eigen::Quaterniond rotation;
    Eigen::Matrix3d intrinsics;
};

struct VelData {
    double sensor_timestamp;
    Eigen::Vector3d vel;
};

class LowLatencyTrackingApi {
    
public:
    LowLatencyTrackingApi();
    
    bool GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation);
    
    void OnAccelerometerDataUpdated(const AccelerometerData& data);
    
    void OnGyroDataUpdated(const GyroData& data);
    
    void OnARKitDataUpdated(const ARKitData& data);
    
    static std::unique_ptr<LowLatencyTrackingApi>& GetInstance();
    
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
    static std::unique_ptr<LowLatencyTrackingApi> low_latency_tracking_api_;
    
    std::deque<AccelerometerData> accelerometer_data_;
    
    std::deque<GyroData> gyro_data_;
    
    std::deque<ARKitData> pos_;
    
    std::deque<VelData> vel_;
    
    std::deque<Quaterniond> q_buf_;
    
    ARKitData last_arkit_data_;
    
    std::mutex accel_mtx_;
    
    std::mutex gyro_mtx_;
    
    std::mutex arkit_mtx_;
    
    bool is_active_ = false;
    
    bool is_filtering_gyro_ = true;
    
    bool is_filtering_acc_ = true;

    // for Interpolation
    AccelerometerData cur_acc;
    std::vector<GyroData> gyro_buf;
    IMUData imu_data;
    int imu_prepare = 0;

    PoseEKF pose_ekf;
    IMUFilter imu_filter;
    
    Vector3d gyro_bias;

    bool ekf_init_flag = false;
    bool imu_good_flag = false;

}; // class LowLatencyTrackingApi

//std::unique_ptr<LowLatencyTrackingApi>& LowLatencyTrackingApi::GetInstance();

} // namespace holokit

#endif /* low_latency_tracking_api_h */
