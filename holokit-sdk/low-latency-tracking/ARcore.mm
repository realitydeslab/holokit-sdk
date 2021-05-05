//
// Created by wya on 2020/11/18.
//

#include <map>
#include <iostream>
#include "ARcore.h"
extern std::string DATASET_TOPIC;
namespace AR
{
    std::string default_output_path;
    Eigen::Matrix4d TIC;
    Eigen::Matrix4d TCI;
//#define Debug_Info

    ARCore::ARCore()
    {
        m_config_file_path_ = "";
        readParameters(m_config_file_path_);
        m_stop_flag = false;
        m_render_cost = 60;
        predicter_running_flag = false;
        process_running_flag = false;
        Viewer_running_flag = false;
        current_event_time = -1;
        m_Estimator_g.setZero();
        m_cur_acc_bias.setZero();
        m_cur_gyr_bias.setZero();
        m_Aligned_Mat = Eigen::Matrix4d::Identity();
        m_Init_Aligned = false;
        predict_pose = std::make_pair(-1.0,Eigen::Matrix4d::Identity());
        m_lIP_buf.reset(new LinearInterpolation_buf_t());
    
    }

    ARCore::~ARCore() {
        if(!m_stop_flag) stop();
    }


    void ARCore::start(double render_cost) {
        m_stop_flag = false;
        m_render_cost = render_cost;

        m_thread_process = std::thread(&ARCore::process, this);

    }

    void ARCore::stop() {
        LOG(WARNING) << "ARCore::stop()";
        m_stop_flag = true;

        m_Arkit.lock();
        m_ARkit_frontend_buf = std::queue<ARkitData>();
        m_ARkit_backend_buf = std::queue<ARkitData>();
        m_Arkit.unlock();

        m_IMU.lock();
        m_IMU_frontend_buf  = std::vector<ImuData>();
        m_IMU_backend_buf  = std::queue<ImuData>();
        m_IMU.unlock();

        m_conPredicter.notify_all();
        std::unique_lock<std::mutex> lkPredicter(m_mutexPredicterMainThread);
        m_conPredicterMainThread.wait_for(lkPredicter, std::chrono::milliseconds(1000), [&]{return !predicter_running_flag;});
        lkPredicter.unlock();
        m_thread_predict.join();

        m_conProcess.notify_all();
        std::unique_lock<std::mutex> lkProcess(m_mutexProcessMainThread);
        m_conProcessMainThread.wait_for(lkProcess, std::chrono::milliseconds(1000), [&] {return !process_running_flag;});
        lkProcess.unlock();
        m_thread_process.join();

        std::unique_lock<std::mutex> lkViewer(m_mutexViewerMainThread);
        m_conViewerMainThread.wait_for(lkViewer, std::chrono::milliseconds(1000), [&] {return !Viewer_running_flag;});
        lkViewer.unlock();
        m_thread_Viewer.join();
    }


    // estimate bias
    void ARCore::process()
    {
        process_running_flag = true;
        m_conProcessMainThread.notify_all();

        while (true)
        {
            // 读取消息  包括IMU信息vector和相对应的图像信息
            std::vector<std::pair<std::vector<ImuData>, ARkitData>> measurements;
            std::unique_lock<std::mutex> lkProcess(m_mutexProcess);
            m_conProcess.wait(lkProcess, [&]
            {
                return (m_stop_flag ||
                (measurements = getMeasurements(m_ARkit_backend_buf,m_IMU_backend_buf)).size() != 0);
            });
            lkProcess.unlock();

#ifdef Debug_Info
            std::cout<<"-------backend---------\n";
            std::cout<<"ARkit size:"<<measurements.size()<<"\n";
            for (int i = 0; i <measurements.size() ; ++i) {
                std::cout<<"ARkit id:"<<measurements[i].second.frame_id<<"\n";
                std::cout<<"IMU size:"<<measurements[i].first.size()<<"\n";
            }
            std::cout<<"-------------------\n";
#endif
            TicToc t_process;

            for (auto& measurement : measurements)
            {
//                if(measurement.first.size() < 2)
//                {
//                    std::cerr<<"IMU lost"<<measurement.first.size()<<"\n";
//                }

                const auto arkit_msg = measurement.second;
                Eigen::Vector3d acc;
                Eigen::Vector3d gyr;
                //IMU信息
                for (auto& imu_msg : measurement.first)
                {
                    double t = imu_msg.inter_event_timestamp;
                    double img_t = arkit_msg.event_timestamp;

                    if (t <= img_t)
                    {
                        // get start time
                        if (current_event_time < 0)
                        {
                            current_event_time = t;
                        }
                        double dt = t - current_event_time;
                        assert(dt >= 0);
                        current_event_time = t;

                        estimator.processIMU(dt, imu_msg.acc, imu_msg.gyr);
                    }
                    else
                    {
                        double dt_1 = img_t - current_event_time;
                        double dt_2 = t - img_t;
                        current_event_time = img_t;
                        double w1 = dt_2 / (dt_1 + dt_2);
                        double w2 = dt_1 / (dt_1 + dt_2);
                        acc = w1 * acc + w2 * imu_msg.acc;
                        gyr = w1 * gyr + w2 * imu_msg.gyr;

                        estimator.processIMU(dt_1, acc, gyr);
                    }
                } //EndFor: IMU parse
                estimator.processARkit(arkit_msg);
                if(estimator.solver_flag == Estimator::SolverFlag::NON_LINEAR )
                {

                    Eigen::Matrix4d Twb = Eigen::Matrix4d::Identity();
                    Twb.block<3,3>(0,0) = estimator.Rs[WINDOW_SIZE];
                    Twb.block<3,1>(0,3) = estimator.Ps[WINDOW_SIZE];

                    m_Predict.lock();
                    m_Estimator_g = estimator.g;
                    m_cur_acc_bias = estimator.Bas[WINDOW_SIZE];
                    m_cur_gyr_bias = estimator.Bgs[WINDOW_SIZE];
                    m_cur_speed = estimator.Vs[WINDOW_SIZE];
                    m_cur_pose_Twb = Twb;
                    m_cur_time = estimator.Headers[WINDOW_SIZE];
                    m_Aligned_Mat = estimator.Tnew_old;
                    m_Init_Aligned = true;
                    m_Predict.unlock();



                    Eigen::Matrix4d old_Twc = estimator.Tnew_old.inverse() * Twb * TIC;
                    Eigen::Matrix4d TWc = GetArkitpose(estimator.ARkit_Info[WINDOW_SIZE]);
//                    std::cout<<"old_Twc:\n"<<old_Twc<<"\n";
//                    std::cout<<"TWc:\n"<<TWc<<"\n";

                }
            }

//            std::cout<<"process cost: "<<t_process.toc()<<"\n";
            if (m_stop_flag)
            {
                LOG(WARNING) << "ARCore::process() stop_flag true";
                process_running_flag = false;
                m_conProcessMainThread.notify_all();
                break;
            }
        }
    }

    std::vector<std::pair<std::vector<ImuData>, AR::ARkitData>> ARCore::getMeasurements
    ( std::queue<ARkitData> & ARkit_buf, std::queue<ImuData> & IMU_buf )
    {
        std::vector<std::pair<std::vector<ImuData>, AR::ARkitData>> measurements;
        while (!ARkit_buf.empty()){
            if (m_stop_flag) return measurements;
            m_Arkit.lock();
            AR::ARkitData feature = ARkit_buf.front();
            ARkit_buf.pop();
            m_Arkit.unlock();

            std::vector<ImuData> imu_buf = getImuMeasurements(feature.event_timestamp, IMU_buf);
            if (imu_buf.empty())
            {
                return measurements;
            }
            measurements.emplace_back(imu_buf, feature);
        }
        return measurements;
    }



    std::vector<ImuData> ARCore::getImuMeasurements(double timestamp, std::queue<ImuData>& buf){
        std::vector<ImuData> imu_measurements;
        if (buf.size() > 100)
        {
            std::cerr << "ARCore::getImuMeasurements error!\n";
        }

        if(buf.front().inter_event_timestamp > timestamp)
        {
            return imu_measurements;

        }
        m_IMU.lock();
        while (!buf.empty() && buf.front().inter_event_timestamp <= timestamp)
        {
            imu_measurements.push_back(buf.front());
            buf.pop();
        }
        m_IMU.unlock();
        return imu_measurements;
    }



    void ARCore::setOutputPath(const std::string& output_path) {
        m_output_path_ = output_path;

        static time_t Time = time(0);
        Time++;
        struct tm tm_t;
#ifdef WIN32
        localtime_s(&tm_t, &gpsTime);
#else
        tm_t = *localtime(&Time);
#endif

        char buf[256];
        strftime(buf, sizeof(buf) - 1, "%Y%m%d%H%M%S", const_cast<tm*>(&tm_t));
        if (m_output_path_.empty())
        {
            default_output_path = default_output_path + "/" + std::string(buf);
        }
        else
        {
            m_output_path_ = m_output_path_ + "/" + std::string(buf);
        }
    }

    void ARCore::addAccMeasurement(const ImuAccData& imu_acc_data) {
        if (m_stop_flag) return;
        TicToc t_addAccMeasurement;


        std::queue<ImuData> New_imu_data;
        ImuAccData trans_imu_acc_data;
        trans_imu_acc_data.event_timestamp = imu_acc_data.event_timestamp;
        trans_imu_acc_data.delivery_timestamp = imu_acc_data.delivery_timestamp;
        trans_imu_acc_data.ax = - 9.81007 * imu_acc_data.ax;
        trans_imu_acc_data.ay = - 9.81007 * imu_acc_data.ay;
        trans_imu_acc_data.az = - 9.81007 * imu_acc_data.az;

        m_lIP.lock();
        m_lIP_buf->addAccel(trans_imu_acc_data, New_imu_data);
        m_lIP.unlock();

        m_IMU.lock();

        while(!New_imu_data.empty())
         {
            m_IMU_frontend_buf.push_back(New_imu_data.front());
            m_IMU_backend_buf.push(New_imu_data.front());
            New_imu_data.pop();
        }

        m_IMU.unlock();
        m_conPredicter.notify_one();//High frequency

        t_addAccMeasurement.tic();
        predict();

    }

    void ARCore::addGyrMeasurement(const ImuGyrData& imu_gyr_data) {
        if (m_stop_flag) return;
        m_lIP.lock();
        m_lIP_buf->addGyro(imu_gyr_data);
        m_lIP.unlock();
    }

    void ARCore::predict()
    {
        //Predict

        //取出所有的IMU
        //首先利用后端优化的状态积分到t0时刻，这里只是为了获得速度,但是t_0又给了一个pose,这个肯定更准，所以在这基础上再进行接下来的积分
        m_Predict.lock();
        if(!m_Init_Aligned)
        {
            m_Predict.unlock();
            return;
        }
        Eigen::Vector3d Estimator_g = m_Estimator_g;
        Eigen::Vector3d cur_acc_bias = m_cur_acc_bias;
        Eigen::Vector3d cur_gyr_bias = m_cur_gyr_bias;
        Eigen::Vector3d cur_speed = m_cur_speed;
        Eigen::Matrix4d cur_pose_Twb = m_cur_pose_Twb;
        double cur_time = m_cur_time;
        Eigen::Matrix4d Aligned_Mat = m_Aligned_Mat;
        m_Predict.unlock();

        m_Arkit.lock();//取出最新的arkitpose 估计的位姿,在这基础上进行插值,这里时间戳定义为t_0
        if(!m_ARkit_frontend_buf.empty() )
            m_arkit_now = m_ARkit_frontend_buf.back();

        while (m_ARkit_frontend_buf.size() > 1)
            m_ARkit_frontend_buf.pop();
        m_Arkit.unlock();

        m_IMU.lock();

        int discard_idx = -1;
        for (int k = 0; k < m_IMU_frontend_buf.size(); ++k)
        {
            if(m_IMU_frontend_buf[k].inter_event_timestamp >= cur_time)
            {
                discard_idx = k;
                break;
            }
            else
            {
                acc_0 = m_IMU_frontend_buf[k].acc;
                gyr_0 = m_IMU_frontend_buf[k].gyr;
                time_0 = m_IMU_frontend_buf[k].inter_event_timestamp;
            }
        }
        m_IMU_frontend_buf = std::vector<ImuData>(m_IMU_frontend_buf.begin() + discard_idx ,m_IMU_frontend_buf.end());



        int inter_idx = -1;//m_vec_imu_data中这个idx之后的都是最新影像的IMU

        //两种情况 1. curtime == m_arkit_now.event_timestamp
        //       2. curtime > m_arkit_now.event_timestamp
        CHECK_LE(cur_time,m_arkit_now.event_timestamp);

        if(fabs(cur_time - m_arkit_now.event_timestamp) < 1e-6 )//case1
            inter_idx = 0;
        CHECK_GT(m_IMU_frontend_buf.size(),1);
        for (int k = 0; k < m_IMU_frontend_buf.size(); ++k)
        {
            m_vec_imu_data.push_back(m_IMU_frontend_buf[k]);
            if(m_IMU_frontend_buf[k].inter_event_timestamp < m_arkit_now.event_timestamp)
            {
                inter_idx = m_vec_imu_data.size();
                if(k + 1 < m_IMU_frontend_buf.size()
                   && m_IMU_frontend_buf[k+1].inter_event_timestamp >= m_arkit_now.event_timestamp)
                {
                    double inter_time = m_arkit_now.event_timestamp;
                    double inter_dt =  m_IMU_frontend_buf[k+1].inter_event_timestamp - m_IMU_frontend_buf[k].inter_event_timestamp;
                    double inter_alpha = (inter_time -  m_IMU_frontend_buf[k].inter_event_timestamp) / inter_dt;
                    ImuData temp_data(inter_time,inter_time,inter_time,inter_time);
                    temp_data.acc = LinearInterpolation(m_IMU_frontend_buf[k].acc,
                                                        m_IMU_frontend_buf[k+1].acc,
                                                        inter_alpha);
                    temp_data.gyr = LinearInterpolation(m_IMU_frontend_buf[k].gyr,
                                                        m_IMU_frontend_buf[k+1].gyr,
                                                        inter_alpha);
                    m_vec_imu_data.push_back(temp_data);
                    inter_idx++;
                }
            }
        }
        CHECK_LT(inter_idx,m_vec_imu_data.size());
        CHECK_GE(inter_idx,1);
        m_IMU.unlock();

        //首先对 cur_time 与 m_arkit_now.event_timestamp之间的速度进行传播
        double latest_time = cur_time;
        CHECK_GT(m_vec_imu_data.size(),0);
        //interplote
        double dt = m_vec_imu_data[0].inter_event_timestamp - time_0;
        double alpha = (latest_time - time_0) / dt;
        acc_0 = LinearInterpolation(acc_0,
                                    m_vec_imu_data[0].acc,
                                    alpha);
        gyr_0 = LinearInterpolation(gyr_0,
                                    m_vec_imu_data[0].gyr,
                                    alpha);

        Eigen::Quaterniond tmp_Q = Eigen::Quaterniond(cur_pose_Twb.block<3,3>(0,0));
        Eigen::Vector3d tmp_P = cur_pose_Twb.block<3,1>(0,3);
        Eigen::Vector3d tmp_V = cur_speed;

        for (int j = 0; j < inter_idx; ++j) {
            double dt = m_vec_imu_data[j].inter_event_timestamp - latest_time;
            latest_time = m_vec_imu_data[j].inter_event_timestamp;
            Eigen::Vector3d linear_acceleration = m_vec_imu_data[j].acc;
            Eigen::Vector3d angular_velocity = m_vec_imu_data[j].gyr;

            Eigen::Vector3d un_acc_0 = tmp_Q * (acc_0 - cur_acc_bias) - Estimator_g;

            Eigen::Vector3d un_gyr = 0.5 * (gyr_0 + angular_velocity) - cur_gyr_bias;
            tmp_Q = tmp_Q * deltaQ(un_gyr * dt);

            Eigen::Vector3d un_acc_1 = tmp_Q * (linear_acceleration - cur_acc_bias) - Estimator_g;

            Eigen::Vector3d un_acc = 0.5 * (un_acc_0 + un_acc_1);

            tmp_P = tmp_P + dt * tmp_V + 0.5 * dt * dt * un_acc;
            tmp_V = tmp_V + dt * un_acc;

            acc_0 = linear_acceleration;
            gyr_0 = angular_velocity;
        }

        CHECK_LT(fabs(latest_time - m_arkit_now.event_timestamp) , 1e-6);

        Eigen::Matrix4d Twc_raw = GetArkitpose(m_arkit_now);
        //trans to estimate frame
        Eigen::Matrix4d Twb_new = Aligned_Mat * GetArkitpose(m_arkit_now) * TCI;
//        std::cout<<"tmp_P1:"<<tmp_P.transpose()<<"\n";
//        std::cout<<"tmp_Q1:"<<tmp_Q.toRotationMatrix()<<"\n";
        tmp_P = Twb_new.block<3,1>(0,3);
        tmp_Q = Eigen::Quaterniond(Twb_new.block<3,3>(0,0));
//        std::cout<<"tmp_P2:"<<tmp_P.transpose()<<"\n";
//        std::cout<<"tmp_Q2:"<<tmp_Q.toRotationMatrix()<<"\n";

        for (int j = inter_idx; j < m_vec_imu_data.size(); ++j) {
            double dt = m_vec_imu_data[j].inter_event_timestamp - latest_time;
            latest_time = m_vec_imu_data[j].inter_event_timestamp;
            Eigen::Vector3d linear_acceleration = m_vec_imu_data[j].acc;
            Eigen::Vector3d angular_velocity = m_vec_imu_data[j].gyr;
            Eigen::Vector3d un_acc_0 = tmp_Q * (acc_0 - cur_acc_bias) - Estimator_g;

            Eigen::Vector3d un_gyr = 0.5 * (gyr_0 + angular_velocity) - cur_gyr_bias;
            tmp_Q = tmp_Q * deltaQ(un_gyr * dt);

            Eigen::Vector3d un_acc_1 = tmp_Q * (linear_acceleration - cur_acc_bias) - Estimator_g;

            Eigen::Vector3d un_acc = 0.5 * (un_acc_0 + un_acc_1);

            tmp_P = tmp_P + dt * tmp_V + 0.5 * dt * dt * un_acc;
            tmp_V = tmp_V + dt * un_acc;

            acc_0 = linear_acceleration;
            gyr_0 = angular_velocity;
        }

        Eigen::Matrix4d Twb_predict  = Eigen::Matrix4d::Identity();
        Twb_predict.block<3,3>(0,0) = tmp_Q.toRotationMatrix();
        Twb_predict.block<3,1>(0,3) = tmp_P;

        Eigen::Matrix4d Tw2_c_predict  = Aligned_Mat.inverse() * Twb_predict * TIC;
        
        m_GetPredictPose.lock();
        predict_pose = std::make_pair(m_vec_imu_data.back().inter_event_timestamp,Tw2_c_predict);
        predict_pose_history.push(std::make_pair(m_vec_imu_data.back().inter_event_timestamp,Tw2_c_predict));

        debug_predict_pose_history.push(std::make_pair(m_vec_imu_data.back().inter_event_timestamp,Tw2_c_predict));
        
        m_GetPredictPose.unlock();
        m_vec_imu_data.clear();

    }

    void ARCore::addARKitMeasurement(const ARkitData& arkit_data)
    {
        if (m_stop_flag) return;
        ARkitData arkit_now = arkit_data;
        Eigen::Matrix4d old_Twc = GetArkitpose(arkit_now);

        Eigen::Matrix4d predict_pose_ = GetArkitpose(arkit_now);

        bool Isinit = false;
        Isinit =GetPoseAtTimestampFordebug(arkit_now.event_timestamp,predict_pose_);

        if(Isinit)
        {
            //gt
            {
                Eigen::Quaterniond Qw2_c  = Eigen::Quaterniond(old_Twc.block<3,3>(0,0));
                Eigen::Vector3d tw2_c  = old_Twc.block<3,1>(0,3);

                std::cout <<"gt:"<< std::to_string(arkit_now.event_timestamp) <<" "<<tw2_c[0]<<" "<<tw2_c[1]<<" "<<tw2_c[2]<<"\n";
            }

            //predict
            {
                
                Eigen::Quaterniond Qw2_c  = Eigen::Quaterniond(predict_pose_.block<3,3>(0,0));
                Eigen::Vector3d tw2_c  = predict_pose_.block<3,1>(0,3);

                std::cout<<"predict:" << std::to_string(arkit_now.event_timestamp) << " "<<tw2_c[0]<<" "<<tw2_c[1]<<" "<<tw2_c[2]<<"\n";
            }
        }

        m_Arkit.lock();
        m_ARkit_frontend_buf.push(arkit_now);
        if(arkit_now.event_timestamp - kf_ARkit_time > 0.1)//10HZ
        {
            kf_ARkit_time = arkit_now.event_timestamp;
            m_ARkit_backend_buf.push(arkit_now);

        }
        m_Arkit.unlock();
        m_conProcess.notify_one(); //Low frequency
        m_conPredicter.notify_one();//High frequency

    }



bool ARCore::GetPoseAtTimestampFordebug(const double need_time,Eigen::Matrix4d & pose) //为了比对真值才弄了这个接口
{
    std::unique_lock<std::mutex> lock(m_GetPredictPose);

    if(predict_pose.first<= 0)
    {
        pose = Eigen::Matrix4d::Identity();
        return false;
    }

    if(need_time <= debug_predict_pose_history.front().first)
    {
        pose = debug_predict_pose_history.front().second;
        return false;
    }
    else if(need_time >= debug_predict_pose_history.back().first)
    {
        pose = debug_predict_pose_history.back().second;
        return true;
    }
    else
    {
        std::pair<double,Eigen::Matrix4d> cur_pose;
        while(1)
        {
            cur_pose = debug_predict_pose_history.front();
            debug_predict_pose_history.pop();
            if(cur_pose.first <= need_time && debug_predict_pose_history.front().first >= need_time)
                break;
        }
        
        pose =  (need_time - cur_pose.first) > (debug_predict_pose_history.front().first - need_time)
        ? debug_predict_pose_history.front().second : cur_pose.second;
        return true;
    }

}

bool ARCore::GetPoseAtTimestamp(const double need_time,Eigen::Matrix4d & pose) //为了比对真值才弄了这个接口
{
    std::unique_lock<std::mutex> lock(m_GetPredictPose);

    if(predict_pose.first<= 0)
    {
        pose = Eigen::Matrix4d::Identity();
        return false;
    }

    if(need_time <= predict_pose_history.front().first)
    {
        pose = predict_pose_history.front().second;
        return false;
    }
    else if(need_time >= predict_pose_history.back().first)
    {
        std::cout<<"diff:"<< fabs((predict_pose_history.back().first - need_time)*1000)<<"\n";
        pose = predict_pose_history.back().second;
        return true;
    }
    else
    {
        std::pair<double,Eigen::Matrix4d> cur_pose;
        while(1)
        {
            cur_pose = predict_pose_history.front();
            predict_pose_history.pop();
            if(cur_pose.first <= need_time && predict_pose_history.front().first >= need_time)
                break;
        }
        
        pose =  (need_time - cur_pose.first) > (predict_pose_history.front().first - need_time)
        ? predict_pose_history.front().second : cur_pose.second;
        
        double small_time = (need_time - cur_pose.first) > (predict_pose_history.front().first - need_time)
        ? predict_pose_history.front().first : cur_pose.first;
        
        std::cout<<"diff:"<< fabs((small_time - need_time)*1000)<<"\n";
        return true;

    }
}

} //namespace AR
