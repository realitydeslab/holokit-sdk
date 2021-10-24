#pragma once

#include <cmath>
#include <cassert>
#include <cstring>
#include "Eigen/Geometry"
#include <vector>
#include <numeric>
#include <functional>
#include <iostream>
#include <iomanip>
using namespace Eigen;
using namespace std;
#define PI                 3.141592653589793f
#define ToRad(x) x*PI/180    // *pi/180
#define ToDeg(x) x*180/PI    // *180/pi
struct CameraParam
{
    double m_inv_K11;
    double m_inv_K13;
    double m_inv_K22;
    double m_inv_K23;
    double m_fx;
    double m_fy;
    double m_cx;
    double m_cy;
    double m_k1;
    double m_k2;
    double m_p1;
    double m_p2;
    bool m_noDistortion;
};
class Utility
{
public:

    static bool interpolation(double t1, const Vector3d &data1, double t2, const Vector3d &data2, double t ,Vector3d &data)
    {
        if(t1 <= t2)
        {
            return false;
        }

        if(fabs(t1-t) < 0.000001)
        {
            data =  data1;
        }

        if(fabs(t2-t) < 0.000001)
        {
            data =  data2;
        }

        double dt1 = t - t1;
        double dt2 = t2 - t;
        data = dt2/(t2-t1)*data1 + dt1/(t2-t1) * data2;
        
        return true;
    }


    template<typename Derived>
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

    template<typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 3, 3> skewSymmetric(const Eigen::MatrixBase<Derived> &q)
    {
        Eigen::Matrix<typename Derived::Scalar, 3, 3> ans;
        ans << typename Derived::Scalar(0), -q(2), q(1),
            q(2), typename Derived::Scalar(0), -q(0),
            -q(1), q(0), typename Derived::Scalar(0);
        return ans;
    }

    template<typename Derived>
    static Eigen::Quaternion<typename Derived::Scalar> positify(const Eigen::QuaternionBase<Derived> &q)
    {
        //printf("a: %f %f %f %f", q.w(), q.x(), q.y(), q.z());
        //Eigen::Quaternion<typename Derived::Scalar> p(-q.w(), -q.x(), -q.y(), -q.z());
        //printf("b: %f %f %f %f", p.w(), p.x(), p.y(), p.z());
        //return q.template w() >= (typename Derived::Scalar)(0.0) ? q : Eigen::Quaternion<typename Derived::Scalar>(-q.w(), -q.x(), -q.y(), -q.z());
        return q;
    }

    template<typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 4, 4> Qleft(const Eigen::QuaternionBase<Derived> &q)
    {
        Eigen::Quaternion<typename Derived::Scalar> qq = positify(q);
        Eigen::Matrix<typename Derived::Scalar, 4, 4> ans;
        ans(0, 0) = qq.w(), ans.template block<1, 3>(0, 1) = -qq.vec().transpose();
        ans.template block<3, 1>(1, 0) = qq.vec(), ans.template block<3, 3>(1, 1) = qq.w()
            * Eigen::Matrix<typename Derived::Scalar, 3, 3>::Identity() + skewSymmetric(qq.vec());
        return ans;
    }

    template<typename Derived>
    static Eigen::Matrix<typename Derived::Scalar, 4, 4> Qright(const Eigen::QuaternionBase<Derived> &p)
    {
        Eigen::Quaternion<typename Derived::Scalar> pp = positify(p);
        Eigen::Matrix<typename Derived::Scalar, 4, 4> ans;
        ans(0, 0) = pp.w(), ans.template block<1, 3>(0, 1) = -pp.vec().transpose();
        ans.template block<3, 1>(1, 0) = pp.vec(), ans.template block<3, 3>(1, 1) = pp.w()
            * Eigen::Matrix<typename Derived::Scalar, 3, 3>::Identity() - skewSymmetric(pp.vec());
        return ans;
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

    template<typename Derived>
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

    static inline Eigen::Matrix4d toEigenInversePose(Eigen::Matrix4d &T)
    {
        Matrix3d R;
        Vector3d t;
        T2Rt(T,R,t);
        Eigen::Matrix4d Tinv;
        Matrix3d Rinv = R.transpose();
        Vector3d tinv = -Rinv*t;

        Rt2T(Rinv,tinv,Tinv);
        return Tinv;
    }

    template <typename T>
    static T constrain_yaw(T _yaw)
    {
        double M_PI_DEG = 180;

        if (_yaw > M_PI_DEG)
        {
            _yaw = _yaw - 2 * M_PI_DEG;
        }
        else if (_yaw < -M_PI_DEG)
        {
            _yaw = _yaw + 2 * M_PI_DEG;
        }
        else
        {
            _yaw = _yaw;
        }

        return _yaw;
    }


    static Eigen::Matrix3d g2R(const Eigen::Vector3d &g);
    static void Rt2T(const Eigen::Matrix3d &R, const Eigen::Vector3d &t, Eigen::Matrix4d &T);
    static void T2Rt(const Eigen::Matrix4d &T, Eigen::Matrix3d &R, Eigen::Vector3d &t);
    static void get_mean_and_stddev(const std::vector<double> &resultSet, double &mean, double &stddev);
    static Eigen::Matrix3d matrix_from_euler(Vector3d ypr);
    static Matrix3d matrix_rotate(Matrix3d m,Vector3d g);
    static double safe_asin(double v);
    static double safe_acos(double v);
    static Quaterniond averageQuaternion(Quaterniond &sum, const Quaterniond &new_q, const Quaterniond &first_q, int num);
    static Quaterniond ConvertToEigenQuaterniond(Eigen::Vector3d euler);
    static Quaterniond averageQuaternionNew(Quaterniond &aver_q, const Quaterniond &new_q, const Quaterniond &first_q, int num);
};
