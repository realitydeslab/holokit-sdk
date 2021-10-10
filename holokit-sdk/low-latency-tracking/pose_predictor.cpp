#include "pose_predictor.h"


namespace holokit {

PosePredictor::PosePredictor()
{
    R_I2C << 0, -1, 0, 1, 0, 0, 0, 0, 1;
}

void PosePredictor::clear()
{
    acc_buf_.clear();
    gyro_buf_.clear();
}

bool PosePredictor::getPredcitPose(Vector3d &pos, Quaterniond &q, const double time)
{
    DELAY_TIME = time;
    calPoseByImu();
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


void PosePredictor::calPoseByImu()   //have imu data
{
   double last_time = last_arkit_data_.sensor_timestamp;
   Eigen::Quaterniond q = last_arkit_data_.rotation;

   Vector3d filtered_gyro(0,0,0);
   Vector3d last_gyro(0,0,0);
   vector<Vector3d> gyro_ratio;
   vector<Quaterniond> q_buf_;  //just smooth current predict q
   for (auto it = gyro_buf_.begin(); it != gyro_buf_.end(); ++it)
   {
       GyroData data = *it;
       //imu_filter.get_filted_gyro(data.rotationRate, filtered_gyro);
       filtered_gyro =  data.rotationRate;
       q *= Utility::ConvertToEigenQuaterniond((data.sensor_timestamp - last_time) * R_I2C * filtered_gyro);
       q.normalize();

       if(last_gyro.norm() > 0)
       {
           Vector3d ratio = (filtered_gyro - last_gyro)/(data.sensor_timestamp - last_time);
           gyro_ratio.push_back(ratio);
//           std::cout << "gyro_ratio " << ratio.norm() << std::endl;
       }

       last_gyro = filtered_gyro;
       q_buf_.push_back(q);

       last_time = data.sensor_timestamp;
   }
   Vector3d predict_ratio(0,0,0);
   for(int i=0; i<gyro_ratio.size();i++)
   {
       predict_ratio += gyro_ratio[i];
   }

   if(gyro_ratio.size() > 0)
   {
       predict_ratio = predict_ratio/gyro_ratio.size();
//       predict_ratio = gyro_ratio[gyro_ratio.size()-1];
   }

   if(predict_ratio.norm() > 50)
   {
       predict_ratio << 0,0,0;
   }

   Vector3d predict_gyro(0,0,0);
#ifdef PREDICT
   predict_gyro = filtered_gyro + predict_ratio * DELAY_TIME;
#else
   predict_gyro = filtered_gyro;
#endif

//   q_buf_.push_back(q);
   Eigen::Quaterniond average_q = q;
   int q_size = q_buf_.size();
   Eigen::Quaterniond sum_q = q;
   Eigen::Quaterniond first_q = q;
#ifdef SMOOTH
   for(int i=q_size-2; i>=0; i--)
   {
//       std::cout << "q " << i << " " << q_buf_[i].coeffs().transpose() << std::endl;
//       std::cout << "ypr" << Utility::R2ypr(q_buf_[i].toRotationMatrix()).transpose() << std::endl;
       double anger_dis = first_q.angularDistance(q_buf_[i]);
//       std::cout << "anger_dis " << anger_dis*57.3 << std::endl;
       if(anger_dis*57.3 > 1)
       {
           break;
       }else
       {
           average_q = Utility::averageQuaternion(sum_q,q_buf_[i],first_q, q_size-i);
//           std::cout << "average ypr" << Utility::R2ypr(average_q.toRotationMatrix()).transpose() << std::endl;
       }
   }
#else
    average_q = q;
#endif
//   std::cout << "filtered_gyro_ratio " << predict_ratio * 57.3 << std::endl;
   average_q *= Utility::ConvertToEigenQuaterniond(DELAY_TIME * R_I2C * 0.5*(filtered_gyro + predict_gyro));
   average_q.normalize();
//   cout << "q " << average_q.coeffs() << endl;
   q_buf_.clear();

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
   Vector3d predict_vel(0,0,0);
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

    Vector3d filtered_acc(0,0,0);
    last_time = last_arkit_data_.sensor_timestamp;

    for (auto it = acc_buf_.begin(); it != acc_buf_.end(); ++it)
    {
        AccelerometerData data = *it;

        imu_filter.get_filted_acc(data.acceleration, filtered_acc);
        double dt = data.sensor_timestamp - last_time;
        p += predict_vel * dt +  q * R_I2C * pow(dt, 2) * filtered_acc / 2 * 9.8;
        last_time = data.sensor_timestamp;
    }

   p += predict_vel * DELAY_TIME /*+  q * R_I2C * pow(DELAY_TIME, 2) * filtered_acc / 2 * 9.8*/;

   position = p;
   rotation = average_q;

}

void PosePredictor::calPoseByInfer()   //have no sensor data
{


}


} // namespace holokit
