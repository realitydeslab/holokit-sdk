#pragma once

#include <iostream>
#include <queue>
#include "Eigen/Geometry"

using namespace Eigen;

template<typename T>
T constrain(T a, T b, T c)
{
    if(a < b)
    {
        a = b;
    }else if(a > c)
    {
        a = c;
    }
    return a;
}

class LowPassFilter
{
 public:
    LowPassFilter(double _sample_freq, double _cutoff_freq);
    void lowpass_filter(const Vector3d &_sample, Vector3d& _out_put);

 private:
    double sample_freq;
    double cutoff_freq;
    double b0;
    double b1;
    double b2;
    double a1;
    double a2;
    Vector3d delay_element_1;
    Vector3d delay_element_2;
};

class IMUFilter{
 public:
    IMUFilter();
    void get_filted_imu(const Vector3d &_acc, const Vector3d &_gyro, Vector3d &_filted_acc, Vector3d &_filted_gyro);
    void get_filted_acc(const Vector3d &_acc, Vector3d &_filted_acc);
    void get_filted_gyro(const Vector3d &_gyro, Vector3d &_filted_gyro);

  private:
    LowPassFilter acc_lwfilter;
    LowPassFilter gyro_lwfilter;
    std::deque<Vector3d> gauss_acc;
    std::deque<Vector3d> gauss_gyro;
    double gauss_para_acc[5] = {0.2,0.2,0.2,0.2,0.2};
    double gauss_para_gyro[5] = {0.2,0.2,0.2,0.2,0.2};
    int gauss_filer_cnt = 0;
    int gauss_acc_filer_cnt = 0;
    int gauss_gyro_filer_cnt = 0;

    //output
    Vector3d filted_acc;
    Vector3d filted_gyro;

};


class IMUProcessor
{
  public:
    IMUProcessor();
    int mayhony_DCM(const Vector3d& _acc, const Vector3d& _gyro, const double _dt);
    Vector3d get_ypr();
  private:
    void reset_dcm();
    int renorm(Vector3d const _a, Vector3d& _result);
    void normalize();
    double P_gain(double _spin_rate);
    void check_matrix();
    void drift_correction();

  private:
    IMUFilter imu_filter;
    //input
    Vector3d acc;
    Vector3d gyro;
    double last_timestamp = 0;
    double delta_t = 0;
    //dcm
    Vector3d omega;
    Vector3d omega_P;
    Vector3d omega_I;

    Vector3d ra_sum;
    double ra_dt = 0;
    Vector3d omega_I_sum;
    double omega_I_sum_time = 0;

    Matrix3d dcm_matrix;
    Vector3d ypr;   //弧度

    //output
    Vector3d neu_ypr;   //弧度
};
