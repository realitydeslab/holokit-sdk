/*

Copyright (c) 2010, Stephan Weiss, ASL, ETH Zurich, Switzerland
You can contact the author at <stephan dot weiss at ieee dot org>

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of ETHZ-ASL nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL ETHZ-ASL BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#ifndef STATE_H_
#define STATE_H_

#include <Eigen/Dense>
#include <Eigen/Geometry>
#include <vector>
#include <iostream>

#define N_STATE 15//25 /// error state size


class State
{
public:
  // states varying during propagation
  Eigen::Vector3d p_;
  Eigen::Vector3d v_;
  Eigen::Quaterniond q_;
  Eigen::Vector3d b_w_;
  Eigen::Vector3d b_a_;

 // states not varying during propagation
  double L_;
  Eigen::Quaterniond q_wv_;
  Eigen::Quaterniond q_ci_;
  Eigen::Vector3d p_ci_;

  // system inputs
  Eigen::Matrix<double,3,1> w_m_;
  Eigen::Matrix<double,3,1> a_m_;

  Eigen::Quaterniond q_int_;

  Eigen::Matrix<double, N_STATE, N_STATE> P_;

  double time_;

  void reset();
};

#endif
