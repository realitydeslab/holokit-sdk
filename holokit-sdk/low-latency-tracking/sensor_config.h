#pragma once

#include <iostream>
#include <Eigen/Eigen>
using namespace Eigen;
#define ACC_NOISE_DENSITY  0.0253//0.08//0.0083   //1.86e-02 //unit: m/(s^2) / sqrt(Hz), continuous-time
#define ACC_RANDOM_WALK    0.000204543326912//0.001//0.00083  //unit: m/(s^3) / sqrt(Hz)

#define ACC_CONST_BIAS_MAX 0.01//unit: m / (s^2)

#define GYRO_NOISE_DENSITY  0.00291//0.06//0.0013   //1.87e-03 //unit: rad/s/sqrt(Hz), continuous-time
#define GYRO_RANDOM_WALK    0.000088056//4e-05  //unit: rad/(s^2)/sqrt(Hz)

struct AccData
{
    double true_timestamp;
    double get_timestamp;
    Vector3d acc;
};

struct GyroData
{
    double true_timestamp;
    double get_timestamp;
    Vector3d gyro;
};

struct ARPose
{
    double true_timestamp;
    double get_timestamp;
    Vector3d t;
    Quaterniond q;
};

struct FusionPose
{
    double true_timestamp;
    double get_timestamp;
    Vector3d t;
    Quaterniond q;
    Vector3d vel;
    Vector3d acc_bias;
    Vector3d gyro_bias;
};
