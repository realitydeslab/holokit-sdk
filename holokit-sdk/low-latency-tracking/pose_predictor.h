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
#define DELAY_TIME 0.04
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
    bool getPredcitPose(Vector3d &position, Quaterniond &q, double dt);
    void setArkitPose(const ARKitData &arkit_data);
    void setAcc(const deque<AccelerometerData> &acc_buf);
    void setGyro(const deque<GyroData> &gyro_buf);

  private:
    void clear();
    void calPoseByImu();   //need imu data
    bool normalPoseByImu();
    bool alignAccAndGyro();
    bool predictLastVel();
    void calPoseByInfer();  //need nothing
    void imuIntegration();
    void smoothAndPredict();
    void predictFutureGyro();
    Quaterniond smoothQ(double deg);
    Vector3d smoothP();
    // Convert from IMU space to camera space
    Eigen::Matrix3d R_I2C;
    IMUFilter imu_filter;

    ARKitData last_arkit_data_;
    deque<ARKitData> arkit_buf_;
    deque<AccelerometerData> acc_buf_;
    deque<GyroData> gyro_buf_;
    deque<GyroData> new_gyro_buf_;  //for align

    deque<ARKitData> pos_;  // arkit data for predit vel
    deque<VelData> vel_;   // for smooth predict vel

    Vector3d predict_last_vel_;  //predict vel in last arkit data
    Vector3d predict_future_vel_;  //predict vel in last arkit data
    Vector3d predict_future_gyro;

    vector<Vector3d> pos_buf_; //for pos smooth
    vector<Quaterniond> q_buf_; //for q smooth

    Vector3d position;   //output
    Quaterniond rotation;
    Vector3d G;

    double predict_dt = 0;
    int still_num = 0;
};
} // namespace holokit
