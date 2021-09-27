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
#import "math_helpers.h"
#import "utility.h"
#import <os/log.h>
#import <os/signpost.h>

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
    
    if (target_timestamp < last_arkit_data_.sensor_timestamp) {
        return false;
    }
#ifdef NO_EKF
   double last_time = last_arkit_data_.sensor_timestamp;
   IMUFilter imu_filter;

   Eigen::Quaterniond q = last_arkit_data_.rotation;
   // Convert from IMU space to camera space
   Eigen::Matrix3d R_I2C;
   R_I2C << 0, -1, 0, 1, 0, 0, 0, 0, 1;

//   std::cout << "[time lag arkit]: " << target_timestamp - last_arkit_data_.sensor_timestamp << std::endl;
//   std::cout << "[time lag]: " << target_timestamp - gyro_data_.back().sensor_timestamp << std::endl;
//   std::cout << "gyro_data_" << gyro_data_.size() << std::endl;
#ifdef GYRO_INTEGRATE
   Vector3d filtered_gyro;
   Vector3d last_gyro(0,0,0);
   vector<Vector3d> gyro_ratio;
   for (auto it = gyro_data_.begin(); it != gyro_data_.end(); ++it) {
       GyroData data = *it;
//       std::cout << "" << Utility::R2ypr(q.toRotationMatrix()) << std::endl;
       if (is_filtering_gyro_) {

//           imu_filter.get_filted_gyro(data.rotationRate, filtered_gyro);
           filtered_gyro = data.rotationRate;
           //std::cout << std::endl;
           //std::cout << "[before filtered]: (" << data.rotationRate(0) << ", " << data.rotationRate(1) << ", " << data.rotationRate(2) << ")" << std::endl;
           //std::cout << "[after filtered]: (" << filtered_gyro(0) << ", " << filtered_gyro(1) << ", " << filtered_gyro(2) << ")" << std::endl;
           q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * filtered_gyro);
           if(last_gyro.norm() > 0)
           {
               Vector3d ratio = (filtered_gyro - last_gyro)/(data.sensor_timestamp - last_time);
               gyro_ratio.push_back(ratio);
               std::cout << "gyro_ratio " << ratio.norm() << std::endl;
           }

           //std::cout << "data.sensor_timestamp - last_time" << data.sensor_timestamp - last_time << std::endl;
           q.normalize();
           //std::cout <<std::fixed << std::setprecision(6) <<  "imu sensor time " << data.sensor_timestamp << std::endl;
           last_gyro = filtered_gyro;
           q_buf_.push_back(q);
       } else {
           q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * data.rotationRate);
           q.normalize();
       }
       last_time = data.sensor_timestamp;
   }
   Vector3d predict_ratio(0,0,0);
   for(int i=0; i<gyro_ratio.size();i++)
   {
       predict_ratio += gyro_ratio[i];
   }
   if(gyro_ratio.size() > 0)
   {
       //predict_ratio = predict_ratio/gyro_ratio.size();
       predict_ratio = gyro_ratio[gyro_ratio.size()-1];
   }

   if(predict_ratio.norm() > 50)
   {
       predict_ratio << 0,0,0;
   }

   Vector3d predict_gyro;
#ifdef PREDICT
    //NSLog(@"[last gyro to current]: %f", [[NSProcessInfo processInfo] systemUptime] - gyro_data_.back().sensor_timestamp);
    
   //predict_gyro = filtered_gyro + predict_ratio * DELAY_TIME;
    
    double delay_time = [[NSProcessInfo processInfo] systemUptime] - gyro_data_.back().sensor_timestamp;
    predict_gyro = filtered_gyro + predict_ratio * DELAY_TIME;
#else
   predict_gyro = filtered_gyro;
#endif
   std::cout << "filtered_gyro_ratio " << predict_ratio * 57.3 << std::endl;
   std::cout << "filtered_gyro " << filtered_gyro*57.3 << std::endl;
   q *= LowLatencyTrackingApi::ConvertToEigenQuaterniond(DELAY_TIME * R_I2C * 0.5*(filtered_gyro + predict_gyro));
   q.normalize();
    q_buf_.push_back(q);
       Eigen::Quaterniond average_q(1,0,0,0);

       Eigen::Quaterniond sum_q = q_buf_[0];
       Eigen::Quaterniond first_q = q_buf_[0];

       for(int i=1; i<q_buf_.size(); i++)
       {
           std::cout << "q " << q_buf_[i].coeffs().transpose() << std::endl;
           std::cout << "ypr" << Utility::R2ypr(q_buf_[i].toRotationMatrix()).transpose() << std::endl;
           double anger_dis = first_q.angularDistance(q_buf_[i]);
           std::cout << "anger_dis " << anger_dis*57.3 << std::endl;
           average_q = Utility::averageQuaternion(sum_q,q_buf_[i],first_q, i+1);
       }
       q_buf_.clear();
    
  //std::cout << "" << Utility::R2ypr(q.toRotationMatrix()) << std::endl;
#endif
   Eigen::Vector3d p = last_arkit_data_.position;

   pos_.push_back(last_arkit_data_);
   //predit vel
   int pos_size = pos_.size();
   double delta_pos_t = 0;
   VelData cur_vel;
   if(pos_size >= 2)
   {
       delta_pos_t = (pos_[pos_size-1].sensor_timestamp - pos_[pos_size-2].sensor_timestamp);
       cur_vel.sensor_timestamp = last_arkit_data_.sensor_timestamp;
       cur_vel.vel = (pos_[pos_size-1].position - pos_[pos_size-2].position)/delta_pos_t;
       vel_.push_back(cur_vel);
   }
   Vector3d predict_vel;
   int vel_size = vel_.size();
   if(delta_pos_t > 0.1)
   {
        predict_vel = cur_vel.vel;
        vel_.clear();
   }else
   {

        for(int i=0; i < vel_size; i++)
        {
            predict_vel = 1/vel_size * vel_[i].vel;
        }
   }

   if(vel_size>=10)
   {
        vel_.pop_front();
   }

    Vector3d filtered_acc;
    last_time = last_arkit_data_.sensor_timestamp;
#ifdef PREDICT
    for (auto it = accelerometer_data_.begin(); it != accelerometer_data_.end(); ++it)
    {
        AccelerometerData data = *it;

        imu_filter.get_filted_acc(data.acceleration, filtered_acc);
        double dt = data.sensor_timestamp - last_time;
        p += predict_vel * dt +  q * R_I2C * pow(dt, 2) * filtered_acc / 2 * 9.8;
        last_time = data.sensor_timestamp;
    }

   p += predict_vel * DELAY_TIME /*+  q * R_I2C * pow(DELAY_TIME, 2) * filtered_acc / 2 * 9.8*/;
#endif
   position = p;
   rotation = q;
#else
    pose_ekf.getRealPose(position, rotation);
    std::cout << "ekf_sum " << pose_ekf.ekf_sum << std::endl;
#endif
    return true;
}

Eigen::Quaterniond LowLatencyTrackingApi::ConvertToEigenQuaterniond(Eigen::Vector3d euler) const {
    return Eigen::AngleAxisd(euler[0], ::Eigen::Vector3d::UnitX()) *
    Eigen::AngleAxisd(euler[1], ::Eigen::Vector3d::UnitY()) *
    Eigen::AngleAxisd(euler[2], ::Eigen::Vector3d::UnitZ());
}

void LowLatencyTrackingApi::OnAccelerometerDataUpdated(const AccelerometerData& data) {
    if (!is_active_) return;
#ifdef NO_EKF
   accel_mtx_.lock();
    
   accelerometer_data_.push_back(data);
   accel_mtx_.unlock();
#else
    cur_acc.acceleration = data.acceleration * 9.81f;
    cur_acc.sensor_timestamp = data.sensor_timestamp;
    if(imu_prepare<10)
     {
//        std::cout << "imu_prepare" <<  imu_prepare << std::endl;
        imu_prepare++;
     }
#endif
}

void LowLatencyTrackingApi::OnGyroDataUpdated(const GyroData& data) {
    if (!is_active_) return;
#ifdef NO_EKF
    gyro_mtx_.lock();

    gyro_data_.push_back(data);
    gyro_mtx_.unlock();
#else
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
        // std::cout << std::fixed << std::setprecision(6)<< "data" << data.sensor_timestamp << std::endl;
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
#endif
}

void LowLatencyTrackingApi::OnARKitDataUpdated(const ARKitData& data) {
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

void LowLatencyTrackingApi::UpdateLastRenderTime() {
    NSLog(@"[last_frame_time]: %f, current time: %f", [[NSProcessInfo processInfo] systemUptime] - last_render_time_, [[NSProcessInfo processInfo] systemUptime]);
    last_render_time_ = [[NSProcessInfo processInfo] systemUptime];
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
UnityHoloKit_UpdateLastRenderTime() {
//    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
//    os_signpost_id_t spid = os_signpost_id_generate(log);
//    os_signpost_interval_begin(log, spid, "EndFrame");
//    holokit::LowLatencyTrackingApi::GetInstance()->UpdateLastRenderTime();
//    os_signpost_interval_end(log, spid, "EndFrame");
}

}
