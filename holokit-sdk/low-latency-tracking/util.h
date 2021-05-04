//
//  util.h
//  holokit
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef util_h
#define util_h

#include <fstream>
#include <iostream>
#include <vector>
#include <ctime>
#include <cstdlib>
#include <chrono>
#include <queue>

#include <Eigen/Dense>

#include "external_struct.h"
namespace AR
{

    #define PI 3.14159265358979
    #define WINDOW_SIZE 20
    extern Eigen::Matrix4d TIC;
    extern Eigen::Matrix4d TCI;
    extern Eigen::Vector3d ACC_BIAS;
    extern Eigen::Vector3d GYR_BIAS;

    extern double ACC_N, ACC_W, GYR_N , GYR_W;

    extern Eigen::Vector3d G;

    extern bool ESTIMATE_EXTRINSIC;

    void inline readParameters(const std::string& config_file_path)
    {
        TIC <<  0.0, 1.0, 0.0,  0.0,
                -1.0, 0.0, 0.0, 0.65,
                0.0,  0.0, 1.0,  0.0,
                0.0,  0.0, 0.0,  1.0;


        TCI = TIC.inverse();
 
    }


    class TicToc
    {
    public:
        TicToc()
        {
            tic();
        }

        void inline tic()
        {
            start = std::chrono::system_clock::now();
        }

        double inline toc()
        {
            end = std::chrono::system_clock::now();
            std::chrono::duration<double> elapsed_seconds = end - start;
            return elapsed_seconds.count() * 1000;
        }

    private:
        std::chrono::time_point<std::chrono::system_clock> start, end;
    };



    template <typename T> T inline LinearInterpolation(const T &a, const T &b, const double t) {
        return a * (1.0 - t) + b * t;
    }

    class LinearInterpolation_buf_t {

        std::deque<double> acc_buf_ts_;
        std::deque<ImuAccData> acc_buf_data_;

        std::vector<double> gyr_buf_ts_;
        std::vector<ImuGyrData> gyr_buf_data_;

    public:
        LinearInterpolation_buf_t() {}

        void inline addAccel(const ImuAccData& imu_acc_data,std::queue<ImuData> & imu_buf)
        {

            if(gyr_buf_ts_.empty())
                return;
            acc_buf_ts_.push_back(imu_acc_data.event_timestamp);
            acc_buf_data_.emplace_back(imu_acc_data);

            while (!acc_buf_ts_.empty())
            {
                double acc_buf_time = acc_buf_ts_.front();
                ImuAccData& front_imu_acc_data = acc_buf_data_.front();
                Eigen::Vector3d acc_buf_data = Eigen::Vector3d{front_imu_acc_data.ax, front_imu_acc_data.ay,front_imu_acc_data.az};

                int first_ge_idx= lower_bound(gyr_buf_ts_.begin(),gyr_buf_ts_.end(),acc_buf_time)-gyr_buf_ts_.begin();

                if( first_ge_idx == 0 )
                {
                    if(fabs(gyr_buf_ts_[first_ge_idx] - acc_buf_time) < 1e-6)
                    {
                        ImuGyrData& tmp_imu_gyr_data = gyr_buf_data_[first_ge_idx];

                        ImuData IMU_msg(front_imu_acc_data.event_timestamp,front_imu_acc_data.delivery_timestamp,
                                        tmp_imu_gyr_data.event_timestamp,tmp_imu_gyr_data.delivery_timestamp);
                        IMU_msg.acc = acc_buf_data;
                        IMU_msg.gyr = Eigen::Vector3d{tmp_imu_gyr_data.wx, tmp_imu_gyr_data.wy,
                                                      tmp_imu_gyr_data.wz};
                        imu_buf.push(IMU_msg);
                    }
                    acc_buf_ts_.pop_front();
                    acc_buf_data_.pop_front();

                }
                else if( first_ge_idx == gyr_buf_ts_.size() )
                {
                    break;
                }
                else
                {

                    if(fabs(gyr_buf_ts_[first_ge_idx] - acc_buf_time) < 1e-6)
                    {
                        ImuGyrData& tmp_imu_gyr_data = gyr_buf_data_[first_ge_idx];

                        ImuData IMU_msg(front_imu_acc_data.event_timestamp,front_imu_acc_data.delivery_timestamp,
                                        tmp_imu_gyr_data.event_timestamp,tmp_imu_gyr_data.delivery_timestamp);

                        IMU_msg.acc = acc_buf_data;
                        IMU_msg.gyr = Eigen::Vector3d{tmp_imu_gyr_data.wx, tmp_imu_gyr_data.wy,
                                                      tmp_imu_gyr_data.wz};
                        imu_buf.push(IMU_msg);

                        acc_buf_ts_.pop_front();
                        acc_buf_data_.pop_front();
                        gyr_buf_ts_ = std::vector<double>(gyr_buf_ts_.begin() + first_ge_idx,gyr_buf_ts_.end());
                        gyr_buf_data_ = std::vector<ImuGyrData>(gyr_buf_data_.begin() + first_ge_idx,gyr_buf_data_.end());

                    } else
                    {
                        double after_gyr_time = gyr_buf_ts_[first_ge_idx];
                        ImuGyrData after_gyr_data = gyr_buf_data_[first_ge_idx];

                        double before_gyr_time = gyr_buf_ts_[first_ge_idx - 1];
                        ImuGyrData before_gyr_data = gyr_buf_data_[first_ge_idx - 1];

                        const double dt = after_gyr_time - before_gyr_time;
                        const double alpha = (acc_buf_time - before_gyr_time) / dt;
                        ImuData IMU_msg(front_imu_acc_data.event_timestamp,front_imu_acc_data.delivery_timestamp,
                                        after_gyr_data.event_timestamp,after_gyr_data.delivery_timestamp);

                        IMU_msg.acc = acc_buf_data;
                        IMU_msg.gyr =  LinearInterpolation(Eigen::Vector3d{before_gyr_data.wx, before_gyr_data.wy,
                                                                           before_gyr_data.wz},
                                                           Eigen::Vector3d{after_gyr_data.wx, after_gyr_data.wy,
                                                                           after_gyr_data.wz},
                                                           alpha);
                        imu_buf.push(IMU_msg);

                        acc_buf_ts_.pop_front();
                        acc_buf_data_.pop_front();
                        gyr_buf_ts_ = std::vector<double>(gyr_buf_ts_.begin() + first_ge_idx-1,gyr_buf_ts_.end());
                        gyr_buf_data_ = std::vector<ImuGyrData>(gyr_buf_data_.begin() + first_ge_idx-1,gyr_buf_data_.end());
                    }
                }
            }
        }



        void inline addGyro(const ImuGyrData & imu_gyr_data){
            gyr_buf_ts_.push_back(imu_gyr_data.event_timestamp);
            gyr_buf_data_.emplace_back(imu_gyr_data);
        }
    };


    template <typename Derived>
    static Eigen::Quaternion<typename Derived::Scalar> deltaQ(const Eigen::MatrixBase<Derived> &theta)
    {
        typedef typename Derived::Scalar Scalar_t;

        Eigen::Quaternion<Scalar_t> dq;
        Eigen::Matrix<Scalar_t, 3, 1> half_theta = theta;
        half_theta /= static_cast<Scalar_t>(2.0);
        dq.w() = static_cast<Scalar_t>(1.0);
        dq.x() = half_theta.x();
        dq.y() = half_theta.y();
        dq.z() = half_theta.z();
        return dq;
    }
    template <typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 3, 3> skewSymmetric(const Eigen::MatrixBase<Derived> &q)
    {
        Eigen::Matrix<typename Derived::Scalar, 3, 3> ans;
        ans << typename Derived::Scalar(0), -q(2), q(1),
                q(2), typename Derived::Scalar(0), -q(0),
                -q(1), q(0), typename Derived::Scalar(0);
        return ans;
    }

    template <typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 4, 4> Qleft(const Eigen::QuaternionBase<Derived> &q)
    {
        Eigen::Quaternion<typename Derived::Scalar> qq = q;

//        Eigen::Quaternion<typename Derived::Scalar> qq = positify(q);
        Eigen::Matrix<typename Derived::Scalar, 4, 4> ans;
        ans(0, 0) = qq.w(), ans.template block<1, 3>(0, 1) = -qq.vec().transpose();
        ans.template block<3, 1>(1, 0) = qq.vec(), ans.template block<3, 3>(1, 1) = qq.w() * Eigen::Matrix<typename Derived::Scalar, 3, 3>::Identity() + skewSymmetric(qq.vec());
        return ans;
    }

    template <typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 4, 4> Qright(const Eigen::QuaternionBase<Derived> &p)
    {
//        Eigen::Quaternion<typename Derived::Scalar> pp = positify(p);
        Eigen::Quaternion<typename Derived::Scalar> pp = p;
        Eigen::Matrix<typename Derived::Scalar, 4, 4> ans;
        ans(0, 0) = pp.w(), ans.template block<1, 3>(0, 1) = -pp.vec().transpose();
        ans.template block<3, 1>(1, 0) = pp.vec(), ans.template block<3, 3>(1, 1) = pp.w() * Eigen::Matrix<typename Derived::Scalar, 3, 3>::Identity() - skewSymmetric(pp.vec());
        return ans;
    }


    static Eigen::Matrix4d GetArkitpose(const ARkitData & cur_arkit_data)
    {
        Eigen::Quaterniond Qwc = Eigen::Quaterniond(cur_arkit_data.ARkit_Rotation.w,
                                                    cur_arkit_data.ARkit_Rotation.x,
                                                    cur_arkit_data.ARkit_Rotation.y,
                                                    cur_arkit_data.ARkit_Rotation.z);
        Qwc.normalized();
        Eigen::Vector3d twc = Eigen::Vector3d(cur_arkit_data.ARkit_Position.x,
                                              cur_arkit_data.ARkit_Position.y,
                                              cur_arkit_data.ARkit_Position.z);
        Eigen::Matrix4d Twc = Eigen::Matrix4d::Identity();
        Twc.block<3, 3>(0, 0) = Qwc.toRotationMatrix();
        Twc.block<3, 1>(0, 3) = twc;

        return Twc;
    }

    static Eigen::Vector3d R2ypr(const Eigen::Matrix3d &R)
    {
        Eigen::Vector3d n = R.col(0);
        Eigen::Vector3d o = R.col(1);
        Eigen::Vector3d a = R.col(2);

        Eigen::Vector3d ypr(3);
        double y = atan2(n(1), n(0));
        double p = atan2(-n(2), n(0) * cos(y) + n(1) * sin(y));
        double r = atan2(a(0) * sin(y) - a(1) * cos(y), -o(0) * sin(y) + o(1) * cos(y));
        ypr(0) = y;
        ypr(1) = p;
        ypr(2) = r;

        return ypr / M_PI * 180.0;
    }

    template <typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 3, 3> ypr2R(const Eigen::MatrixBase<Derived> &ypr)
    {
        typedef typename Derived::Scalar Scalar_t;

        Scalar_t y = ypr(0) / 180.0 * M_PI;
        Scalar_t p = ypr(1) / 180.0 * M_PI;
        Scalar_t r = ypr(2) / 180.0 * M_PI;

        Eigen::Matrix<Scalar_t, 3, 3> Rz;
        Rz << cos(y), -sin(y), 0,
                sin(y), cos(y), 0,
                0, 0, 1;

        Eigen::Matrix<Scalar_t, 3, 3> Ry;
        Ry << cos(p), 0., sin(p),
                0., 1., 0.,
                -sin(p), 0., cos(p);

        Eigen::Matrix<Scalar_t, 3, 3> Rx;
        Rx << 1., 0., 0.,
                0., cos(r), -sin(r),
                0., sin(r), cos(r);

        return Rz * Ry * Rx;
    }

    static Eigen::Matrix3d g2R(const Eigen::Vector3d &g)
    {
        Eigen::Matrix3d R0;
        Eigen::Vector3d ng1 = g.normalized();
        Eigen::Vector3d ng2{0, 0, 1.0};
        R0 = Eigen::Quaterniond::FromTwoVectors(ng1, ng2).toRotationMatrix();
        double yaw = R2ypr(R0).x();
        R0 = ypr2R(Eigen::Vector3d{-yaw, 0, 0}) * R0;
        // R0 = Utility::ypr2R(Eigen::Vector3d{-90, 0, 0}) * R0;
        return R0;
    }

    enum SIZE_PARAMETERIZATION
    {
        SIZE_POSE_R = 4,
        SIZE_POSE_T = 3,
        SIZE_SPEED = 3,
        SIZE_BIAS_ACC = 3,
        SIZE_BIAS_GYR = 3,

    };

    enum StateOrder
    {
        O_P = 0,
        O_R = 3,
        O_V = 6,
        O_BA = 9,
        O_BG = 12
    };

    enum NoiseOrder
    {
        O_AN = 0,
        O_GN = 3,
        O_AW = 6,
        O_GW = 9
    };


}

#endif /* util_h */
