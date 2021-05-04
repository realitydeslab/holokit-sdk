//
//  pose_local_parameterization.cpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#include "pose_local_parameterization.h"

bool PoseLocalParameterization::Plus(const double *x, const double *delta, double *x_plus_delta) const
{
	Eigen::Map<const Eigen::Quaterniond> _q(x);

	Eigen::Vector3d half_delta = Eigen::Map<const Eigen::Vector3d>(delta);
	half_delta.array() /= 2.0;

    Eigen::Quaterniond _dq;
    _dq.w() = 1.0;
    _dq.x() = half_delta.x();
    _dq.y() = half_delta.y();
    _dq.z() = half_delta.z();

    Eigen::Map<Eigen::Quaterniond> q(x_plus_delta);
    q = (_q * _dq).normalized();

    return true;
}

bool PoseLocalParameterization::ComputeJacobian(const double *x,
                                                double *jacobian) const {

    jacobian[0] = 1.0; jacobian[1] = 0.0;jacobian[2] = 0.0;
    jacobian[3] = 0.0; jacobian[4] = 1.0;jacobian[5] = 0.0;
    jacobian[6] = 0.0; jacobian[7] = 0.0;jacobian[8] = 1.0;
    jacobian[9] = 0.0; jacobian[10] = 0.0;jacobian[11] = 0.0;
    return true;
}
