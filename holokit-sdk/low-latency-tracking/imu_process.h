#pragma once

#include <iostream>
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
    void lowpass_filter(const Vector3d& _sample, Vector3d& _out_put);

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
    Vector3d gauss_acc[5];
    Vector3d gauss_gyro[5];
    double gauss_para_acc[5] = {0.2,0.2,0.2,0.2,0.2};
    double gauss_para_gyro[5] = {0.2,0.2,0.2,0.2,0.2};
    int gauss_filer_cnt = 0;

    //output
    Vector3d filted_acc;
    Vector3d filted_gyro;

};

