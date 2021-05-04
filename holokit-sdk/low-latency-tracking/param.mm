//
//  param.cpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//
#include "util.h"
namespace AR
{
    Eigen::Vector3d ACC_BIAS{0,0,0};
    Eigen::Vector3d GYR_BIAS{0,0,0};

    double ACC_N = 0.0253, ACC_W = 0.000204543326912;
    double GYR_N = 0.00291    , GYR_W = 0.000088056 ;

    Eigen::Vector3d G{0.0, 0.0, 9.81007};

    bool ESTIMATE_EXTRINSIC = false;
}
