#include "pose_predictor.h"


namespace holokit {

PosePredictor::PosePredictor()
{
    R_I2C << 0, -1, 0, 1, 0, 0, 0, 0, 1;
    G << 0, -9.8, 0;
    predict_last_vel_ << 0, 0, 0;
    predict_future_gyro << 0, 0, 0;

    position << 0, 0, 0;   //output
    rotation = Quaterniond(1,0,0,0);

}

void PosePredictor::clear()
{
    acc_buf_.clear();
    gyro_buf_.clear();
    q_buf_.clear();  //只平滑本次估计
    pos_buf_.clear();
    new_gyro_buf_.clear();
}

bool PosePredictor::getPredcitPose(Vector3d &pos, Quaterniond &q, double dt)
{
//    predict_dt = dt;
//    Vector3d sum_w(0,0,0);
//    for(int i=0; i<gyro_buf_.size(); i++)
//    {
//        sum_w += gyro_buf_[i].rotationRate;
//    }
//    Vector3d aver_w = sum_w/gyro_buf_.size();
//    cout << "aver_w" <<aver_w.norm() << endl;
//    if(aver_w.norm() < 0.02)
//    {
//        still_num++;
//    }else{
//        still_num = 0;
//    }
//
//    if(still_num > 600 )
//    {
//        pos = last_arkit_data_.position;
//        q = last_arkit_data_.rotation;
//        return true;
//    }
    normalPoseByImu();
    pos = position;
    q = rotation;
    clear();
    return true;
}

void PosePredictor::setArkitPose(const ARKitData &arkit_data)
{
    last_arkit_data_ = arkit_data;
}

void PosePredictor::setAcc(const deque<AccelerometerData> &acc_buf)
{
    acc_buf_ = acc_buf;
}

void PosePredictor::setGyro(const deque<GyroData> &gyro_buf)
{
    gyro_buf_ = gyro_buf;
}


bool PosePredictor::alignAccAndGyro()
{
    double last_arkit_time = last_arkit_data_.sensor_timestamp;
    if(gyro_buf_.size() < 2) //gyro为空或者只有1个，则无需计算
    {
        return false;
    }
    if(acc_buf_.size() < 2) //acc为空或者只有1个，则只计算姿态
    {
        return false;
    }
    //虚拟出对应last arkit 的 gyro  acc  这里没写容错机制
    Vector3d gyro0(0,0,0);
    Vector3d acc0(0,0,0);
    Utility::interpolation(gyro_buf_[0].sensor_timestamp, gyro_buf_[0].rotationRate, gyro_buf_[1].sensor_timestamp, gyro_buf_[1].rotationRate, last_arkit_time, gyro0);
    Utility::interpolation(acc_buf_[0].sensor_timestamp, acc_buf_[0].acceleration, acc_buf_[1].sensor_timestamp, acc_buf_[1].acceleration, last_arkit_time, acc0);

    AccelerometerData acc_data = {last_arkit_time, acc0};
    acc_buf_.pop_front();
    acc_buf_.push_front(acc_data);

    GyroData gyro_data = {last_arkit_time, gyro0};
    gyro_buf_.pop_front();
    gyro_buf_.push_front(gyro_data);
//    new_gyro_buf_.push_back(gyro_data);

//    int gyro_size = gyro_buf_.size();
//    int acc_size = acc_buf_.size();

//    for(int i=1; i< acc_size; i++)  // 以a为准虚拟出对应的w 以a时间戳为准，故遍历a
//    {
//
//        if(acc_buf_[i].sensor_timestamp < gyro_buf_[i].sensor_timestamp)
//        {
//            Vector3d gyro(0,0,0);
//            Utility::interpolation(gyro_buf_[i-1].sensor_timestamp, gyro_buf_[i-1].rotationRate,gyro_buf_[i].sensor_timestamp, gyro_buf_[i].rotationRate,acc_buf_[i].sensor_timestamp,gyro);
//            GyroData gyro_data = {acc_buf_[i].sensor_timestamp, gyro};
//            new_gyro_buf_.push_back(gyro_data);
//        }else{
//            if(i == gyro_size-1) //gyro数量少于acc，已经是gyro最后一帧，无法插值
//            {
//                new_gyro_buf_.push_back(gyro_buf_[i]);
//                break;
//            }
//            Vector3d gyro;
//            Utility::interpolation(gyro_buf_[i].sensor_timestamp, gyro_buf_[i].rotationRate,gyro_buf_[i+1].sensor_timestamp, gyro_buf_[i+1].rotationRate,acc_buf_[i].sensor_timestamp,gyro);
//            GyroData gyro_data = {acc_buf_[i].sensor_timestamp, gyro};
//            new_gyro_buf_.push_back(gyro_data);
//        }
//    }
//
//    if(gyro_size > acc_size) //gyro数量大于acc，把后面的几帧加入
//    {
//        for(int i = acc_size; i< gyro_size; i++)
//        {
//            new_gyro_buf_.push_back(gyro_buf_[i]);
//        }
//    }
    return true;
}

bool PosePredictor::predictLastVel()
{
    pos_.push_back(last_arkit_data_);
    int pos_size = pos_.size();
    if(pos_size < 2)
    {
        return false;
    }
    
    //predit vel
    double delta_pos_t = 0;
    VelData last_vel;
    
    delta_pos_t = (pos_[pos_size-1].sensor_timestamp - pos_[pos_size-2].sensor_timestamp);
    last_vel.sensor_timestamp = last_arkit_data_.sensor_timestamp;
    last_vel.vel = (pos_[pos_size-1].position - pos_[pos_size-2].position)/delta_pos_t;
    vel_.push_back(last_vel);
    
    Vector3d predict_vel(0,0,0);
    int vel_size = vel_.size();
    if(delta_pos_t > 0.1)
    {
        predict_last_vel_ = last_vel.vel;
        vel_.clear();
    }else
    {
        predict_vel = vel_[0].vel;
        for(int i=1; i < vel_size; i++)
        {
            predict_vel = (2 * vel_[i].vel + i * predict_vel)/(i+2);
        }
    }
    
    if(vel_size>=10)
    {
        vel_.pop_front();
    }
    return true;
}

void PosePredictor::imuIntegration()
{

    Quaterniond q = last_arkit_data_.rotation;
    Vector3d pos = last_arkit_data_.position;
    Vector3d vel = predict_last_vel_;
    for(int i=0; i<acc_buf_.size()-1; i++)
    {
        Vector3d un_acc0 = q * R_I2C * acc_buf_[i].acceleration * 9.8 - G;;
        if(i < gyro_buf_.size()-1)   //已经没有gyro数据,就用最终的姿态
        {
            Vector3d un_gyro = 0.5 * (gyro_buf_[i].rotationRate + gyro_buf_[i+1].rotationRate);
            q *= Utility::ConvertToEigenQuaterniond((gyro_buf_[i+1].sensor_timestamp - gyro_buf_[i].sensor_timestamp) * R_I2C * un_gyro);
            q.normalize();
            q_buf_.push_back(q);
        }
        Vector3d un_acc1 = q * R_I2C * acc_buf_[i+1].acceleration * 9.8 - G;
        Vector3d un_acc = 0.5 * (un_acc0 + un_acc1);
        double dt = acc_buf_[i+1].sensor_timestamp - acc_buf_[i].sensor_timestamp;
        pos += vel * dt + 0.5 * dt * dt * un_acc;
        vel += dt * un_acc;
        pos_buf_.push_back(pos);
    }
    //gyro数据有多的
    if(gyro_buf_.size() > acc_buf_.size())
    {
        for(int i = acc_buf_.size()-1; i < gyro_buf_.size()-1; i++)
        {
            Vector3d un_gyro = 0.5 * (gyro_buf_[i].rotationRate + gyro_buf_[i+1].rotationRate);
            q *= Utility::ConvertToEigenQuaterniond((gyro_buf_[i+1].sensor_timestamp - gyro_buf_[i].sensor_timestamp) * R_I2C * un_gyro);
            q.normalize();
            q_buf_.push_back(q);
        }
    }
    predict_future_vel_ = vel;
    rotation = q;
    position = pos;
}

//EMA
void PosePredictor::predictFutureGyro()
{
    predict_future_gyro = gyro_buf_[0].rotationRate;
    for(int i=1; i<gyro_buf_.size(); i++)
    {
        predict_future_gyro = (2 * gyro_buf_[i].rotationRate + i * predict_future_gyro)/(i+2);
    }
}

Quaterniond PosePredictor::smoothQ(double deg)
{
    Eigen::Quaterniond average_q = q_buf_.back();
    int q_size = q_buf_.size();
    Eigen::Quaterniond sum_q = average_q;
    Eigen::Quaterniond first_q = average_q;
    for(int i=q_size-2; i>=0; i--)    //先对有imu的姿态做平滑
    {
//        std::cout << "q " << i << " " << q_buf_[i].coeffs().transpose() << std::endl;
//        std::cout << "ypr" << Utility::R2ypr(q_buf_[i].toRotationMatrix()).transpose() << std::endl;
        double angel_dis = first_q.angularDistance(q_buf_[i]);
//        std::cout << "anger_dis " << angel_dis*57.3 << std::endl;
        if(angel_dis*57.3 > deg)
        {
            break;
        }else
        {
            //average_q = Utility::averageQuaternion(sum_q,q_buf_[i],first_q, q_size-i);
            average_q = Utility::averageQuaternionNew(average_q, q_buf_[i], first_q,q_size-i);
//            std::cout << "average ypr" << Utility::R2ypr(average_q.toRotationMatrix()).transpose() << std::endl;
        }
    }

    return average_q;

}

Vector3d PosePredictor::smoothP()
{
    Vector3d average_p = pos_buf_.back();
    for(int i=1; i < pos_buf_.size(); i++)
    {
        average_p = (2 * pos_buf_[i] + i * average_p)/(i+2);
    }
    return average_p;
}

void PosePredictor::smoothAndPredict()
{
//    Quaterniond average_q = smoothQ(0.1);
    Quaterniond average_q = q_buf_.back();
    predictFutureGyro();
    //predict future q
    average_q *= Utility::ConvertToEigenQuaterniond(predict_dt * R_I2C * predict_future_gyro);
    average_q.normalize();
    q_buf_.push_back(average_q);

    //再次平滑
    average_q = smoothQ(0.3); // TODO: KE YI TIAO! Increasing this value will cause better smoothness and higher latency. Vice versa. The range should between 0 and 0.5. 0 means no smoothness.
    rotation = average_q;

    position += predict_last_vel_ * predict_dt;
    pos_buf_.push_back(position);
    position = smoothP();
    
    
}

bool PosePredictor::normalPoseByImu()
{
      alignAccAndGyro();

      predictLastVel();

      imuIntegration();

      smoothAndPredict();

      return true;
}

//void PosePredictor::calPoseByImu()   //have imu data
//{
//   double last_time = last_arkit_data_.sensor_timestamp;
//   Eigen::Quaterniond q = last_arkit_data_.rotation;

//   Vector3d filtered_gyro(0,0,0);
//   Vector3d pre_filtered_gyro(0,0,0);
//   Vector3d last_gyro(0,0,0);
//   vector<Vector3d> gyro_ratio;
//   vector<Quaterniond> q_buf_;  //just smooth current predict q
//   for (auto it = gyro_buf_.begin(); it != gyro_buf_.end(); ++it)
//   {
//       GyroData data = *it;
//       imu_filter.get_filted_gyro(data.rotationRate, pre_filtered_gyro);
//       filtered_gyro =  data.rotationRate;
//       q *= Utility::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * filtered_gyro);
//       q.normalize();

//       if(last_gyro.norm() > 0)
//       {
//           Vector3d ratio = (filtered_gyro - last_gyro)/(data.sensor_timestamp - last_time);
//           gyro_ratio.push_back(ratio);
//           std::cout << "gyro_ratio " << ratio.norm() << std::endl;
//       }

//       last_gyro = filtered_gyro;
//       q_buf_.push_back(q);

//       last_time = data.sensor_timestamp;
//   }
//   Vector3d predict_ratio(0,0,0);
//   for(int i=0; i<gyro_ratio.size();i++)
//   {
//       predict_ratio += gyro_ratio[i];
//   }

//   if(gyro_ratio.size() > 0)
//   {
//       predict_ratio = predict_ratio/gyro_ratio.size();
////       predict_ratio = gyro_ratio[gyro_ratio.size()-1];
//   }

//   if(predict_ratio.norm() > 50)
//   {
//       predict_ratio << 0,0,0;
//   }

//   Vector3d predict_gyro(0,0,0);
//#ifdef PREDICT
//   predict_gyro = filtered_gyro + predict_ratio * DELAY_TIME;
//#else
//   predict_gyro = pre_filtered_gyro;
//#endif

////   q_buf_.push_back(q);
//   Eigen::Quaterniond average_q = q;
//   int q_size = q_buf_.size();
//   Eigen::Quaterniond sum_q = q;
//   Eigen::Quaterniond first_q = q;
//#ifdef SMOOTH
//   for(int i=q_size-2; i>=0; i--)
//   {
//       std::cout << "q " << i << " " << q_buf_[i].coeffs().transpose() << std::endl;
//       std::cout << "ypr" << Utility::R2ypr(q_buf_[i].toRotationMatrix()).transpose() << std::endl;
//       double anger_dis = first_q.angularDistance(q_buf_[i]);
//       std::cout << "anger_dis " << anger_dis*57.3 << std::endl;
//       if(anger_dis*57.3 > 1)
//       {
//           break;
//       }else
//       {
//           average_q = Utility::averageQuaternion(sum_q,q_buf_[i],first_q, q_size-i);
//           std::cout << "average ypr" << Utility::R2ypr(average_q.toRotationMatrix()).transpose() << std::endl;
//       }
//   }
//#else
//    average_q = q;
//#endif
//   std::cout << "filtered_gyro_ratio " << predict_ratio * 57.3 << std::endl;
//   average_q *= Utility::ConvertToEigenQuaterniond(DELAY_TIME * R_I2C * 0.5*(filtered_gyro + predict_gyro));
//   average_q.normalize();
//   cout << "q " << average_q.coeffs() << endl;
//   q_buf_.clear();

//   Eigen::Vector3d p = last_arkit_data_.position;



////    Vector3d filtered_acc(0,0,0);
////    last_time = last_arkit_data_.sensor_timestamp;

////    for (auto it = acc_buf_.begin(); it != acc_buf_.end(); ++it)
////    {
////        AccelerometerData data = *it;

////        imu_filter.get_filted_acc(data.acceleration, filtered_acc);
////        double dt = data.sensor_timestamp - last_time;
////        p += predict_vel * dt +  q * R_I2C * pow(dt, 2) * filtered_acc / 2 * 9.8;
////        last_time = data.sensor_timestamp;
////    }

////   p += predict_vel * DELAY_TIME /*+  q * R_I2C * pow(DELAY_TIME, 2) * filtered_acc / 2 * 9.8*/;

//   position = p;
//   rotation = average_q;

//}

void PosePredictor::calPoseByInfer()   //have no sensor data
{


}


} // namespace holokit
