//
//  test.h
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef ARcore_h
#define ARcore_h

#include <map>
#include <queue>
#include <vector>

#include <thread>
#include <chrono>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <iostream>
#include <fstream>
#include <Eigen/Dense>


#include "util.h"
#include "estimator.h"
namespace AR{

    class ARCore {

    public:

        ARCore();

        ~ARCore();

        void start(double render_cost);

        void stop();

        void setOutputPath(const std::string& output_path);

        void addAccMeasurement(const ImuAccData& imu_acc_data);

        void addGyrMeasurement(const ImuGyrData& imu_gyr_data);

        void addARKitMeasurement(const ARkitData& arkit_data);

        bool GetPoseAtTimestamp(Eigen::Matrix4d & pose); //返回最新的预测的pose,与IMU的delay一致,基本忽略不计,pose from world to cam
        bool GetPoseAtTimestamp(const double need_time, Eigen::Matrix4d & pose); //返回距离这个时间最近的预测,IMU频率很快，没必要再用匀速模型猜测

    private:
        void predict();
        std::pair<double,Eigen::Matrix4d> predict_pose; //double 是event时间戳
        std::mutex m_GetPredictPose;

        std::unique_ptr<LinearInterpolation_buf_t> m_lIP_buf;

        Estimator estimator;

        //最后一次的estimate的数据
        Eigen::Vector3d m_Estimator_g;
        Eigen::Vector3d m_cur_acc_bias;
        Eigen::Vector3d m_cur_gyr_bias;
        Eigen::Vector3d m_cur_speed;
        Eigen::Matrix4d m_cur_pose_Twb;
        double m_cur_time;
        Eigen::Matrix4d m_Aligned_Mat;
        bool m_Init_Aligned;

        std::mutex m_Predict;
        ARkitData m_arkit_now;
        std::vector<ImuData> m_vec_imu_data;
        Eigen::Vector3d acc_0, gyr_0;
        double time_0;

        void process(); // estimate bias

        std::vector<std::pair<std::vector<ImuData>, AR::ARkitData>> getMeasurements
                (std::queue<ARkitData> & ARkit_buf, std::queue<ImuData> & IMU_buf);
        std::vector<ImuData> getImuMeasurements(double timestamp, std::queue<ImuData>& buf);


        std::string m_config_file_path_;
        bool m_stop_flag;
        double m_render_cost; // ms

        double current_event_time;

        std::queue<ARkitData> m_ARkit_frontend_buf;
        std::queue<ARkitData> m_ARkit_backend_buf;

        double kf_ARkit_time = -1.0;

        std::vector<ImuData> m_IMU_frontend_buf;
        std::queue<ImuData> m_IMU_backend_buf;

        std::thread m_thread_predict;
        std::thread m_thread_process;
        std::thread m_thread_Viewer;


        bool predicter_running_flag;
        bool process_running_flag;
        bool Viewer_running_flag;

        std::mutex m_Arkit;
        std::mutex m_IMU;
        std::mutex m_lIP;
        
        std::mutex  m_mutexPredicterMainThread;
        std::mutex  m_mutexProcessMainThread;
        std::mutex  m_mutexViewerMainThread;

        std::mutex  m_mutexPredicter;
        std::mutex  m_mutexProcess;
        std::mutex  m_mutex_CamPose;

        std::condition_variable m_conPredicterMainThread;
        std::condition_variable m_conPredicter;
        std::condition_variable m_conProcessMainThread;
        std::condition_variable m_conProcess;
        std::condition_variable m_conViewerMainThread;

        std::string m_output_path_;

        //debug
        std::vector<std::pair<double,Eigen::Matrix4d>> predict_pose_history;

    };

} // namespace AR



#endif /* test_h */
