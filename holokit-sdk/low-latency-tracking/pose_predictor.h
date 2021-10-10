#pragma once

#include <Eigen/Eigen>
#include <deque>
#include <mutex>
#include <memory>
#include "imu_process.h"
#include "utility.h"

using namespace Eigen;
using namespace std;

#define GYRO_INTEGRATE

//#define PREDICT
#define SMOOTH
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

class PosePredictor
{
  public:
    PosePredictor();
    bool getPredcitPose(Vector3d &position, Quaterniond &q, const double time);
    void setArkitPose(const ARKitData &arkit_data);
    void setAcc(const deque<AccelerometerData> &acc_buf);
    void setGyro(const deque<GyroData> &gyro_buf);

  private:
    void clear();
    void calPoseByImu();   //need imu data
    void calPoseByInfer();  //need nothing
    // Convert from IMU space to camera space
    Eigen::Matrix3d R_I2C;
    IMUFilter imu_filter;
    double DELAY_TIME = 0.040;

    ARKitData last_arkit_data_;
    deque<ARKitData> arkit_buf_;
    deque<AccelerometerData> acc_buf_;
    deque<GyroData> gyro_buf_;

    deque<ARKitData> pos_;
    deque<VelData> vel_;

    Vector3d predict_vel;
    Vector3d predict_w_acc;

    Vector3d position;   //output
    Quaterniond rotation;

};
} // namespace holokit
