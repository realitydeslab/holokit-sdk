//
//  pose_local_parameterization.cpp
//  test-headtracking2
//
//  Created by Botao Hu on 11/28/20.
//

#include "pose_local_parameterization.h"

#include <algorithm>
#include "Eigen/Geometry"
#include "ceres/internal/eigen.h"
#include "ceres/internal/fixed_array.h"
#include "ceres/rotation.h"
#include "glog/logging.h"


namespace ceres {

bool PoseLocalParameterization::Plus(const double *x,
                                     const double *delta,
                                     double *x_plus_delta) const {
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

bool PoseLocalParameterization::ComputeJacobian(const double* x,
                                                double* jacobian) const {
  jacobian[0]  = 1.0; jacobian[1]  = 0.0; jacobian[2]  = 0.0;
  jacobian[3]  = 0.0; jacobian[4]  = 1.0; jacobian[5]  = 0.0;
  jacobian[6]  = 0.0; jacobian[7]  = 0.0; jacobian[8]  = 1.0;
  jacobian[9]  = 0.0; jacobian[10] = 0.0; jacobian[11] = 0.0;
  return true;
}

}  // namespace ceres
