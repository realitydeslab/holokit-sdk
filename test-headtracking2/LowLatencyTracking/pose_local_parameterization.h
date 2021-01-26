//
//  pose_local_parameterization.h
//  holokit
//
//  Created by Botao Hu on 11/28/20.
//


#ifndef CERES_PUBLIC_POSE_LOCAL_PARAMETERIZATION_H_
#define CERES_PUBLIC_POSE_LOCAL_PARAMETERIZATION_H_

#include <vector>
#include "ceres/local_parameterization.h"
#include "ceres/internal/port.h"
#include "ceres/internal/disable_warnings.h"

namespace ceres {

class CERES_EXPORT PoseLocalParameterization : public ceres::LocalParameterization {
 public:
  virtual ~PoseLocalParameterization() {}
  virtual bool Plus(const double *x,
                    const double *delta,
                    double *x_plus_delta) const;
  virtual bool ComputeJacobian(const double *x, double *jacobian) const;
  virtual int GlobalSize() const { return 4; };
  virtual int LocalSize() const { return 3; };
};
}

#endif /* pose_local_parameterization_h */
