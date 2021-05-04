//
//  pose_local_parameterization.hpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef pose_local_parameterization_h
#define pose_local_parameterization_h

#include <Eigen/Dense>
#include "factor.h"


class PoseLocalParameterization : public ceres::LocalParameterization {
	public:
		virtual ~PoseLocalParameterization(){}
		virtual bool Plus(const double *x, const double *delta, double *x_plus_delta) const;
		virtual bool ComputeJacobian(const double *x, double *jacobian) const;
		virtual int GlobalSize() const { return 4; };
		virtual int LocalSize() const { return 3; };

};

#endif /* pose_local_parameterization_hpp */
