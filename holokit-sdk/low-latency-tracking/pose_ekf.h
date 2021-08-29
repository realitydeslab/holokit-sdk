
#ifndef PoseEKF_H_
#define PoseEKF_H_


#include <Eigen/Eigen>
#include <vector>
#include "state.h"
#include "sensor_config.h"

#define N_STATE_BUFFER 256
#define HLI_EKF_STATE_SIZE 16
class PoseEKF
{

public:
  typedef Eigen::Matrix<double, N_STATE, 1> ErrorState;
  typedef Eigen::Matrix<double, N_STATE, N_STATE> ErrorStateCov;

  PoseEKF();
void initialize(const Eigen::Vector3d & p, const Eigen::Vector3d & v,
                          const Eigen::Quaterniond & q, const Eigen::Vector3d & b_w,
                          const Eigen::Vector3d & b_a, const double & L,
                          const Eigen::Quaterniond & q_wv, const Eigen::Matrix<double, N_STATE, N_STATE> & P,
                          const Eigen::Vector3d & w_m, const Eigen::Vector3d & a_m,
                          const Eigen::Vector3d & g, const Eigen::Quaterniond & q_ci,
                          const Eigen::Vector3d & p_ci,const double time_stamp);

  unsigned char getClosestState(State* timestate, double tstamp, double delay = 0.00);

  bool getStateAtIdx(State* timestate, unsigned char idx);


public:
  const static int nBuff_ = 30;
  const static int nMaxCorr_ = 50;
  const static int QualityThres_ = 1e3;

  Eigen::Matrix<double, N_STATE, N_STATE> Fd_;
  Eigen::Matrix<double, N_STATE, N_STATE> Qd_;

  /// state variables
  State StateBuffer_[N_STATE_BUFFER];
  unsigned char idx_state_;
  unsigned char idx_P_;
  unsigned char idx_time_;
  Eigen::Vector3d g_;

  int qvw_inittimer_;
  Eigen::Matrix<double, nBuff_, 4> qbuff_;
  /// correction from EKF update
  Eigen::Matrix<double, N_STATE, 1> correction_;


  Eigen::Matrix3d R_IW_;
  Eigen::Matrix3d R_CI_;
  Eigen::Matrix3d R_WV_;

  bool initialized_;
  bool predictionMade_;


  bool data_playback_;

  void propagateState(const double dt);

  void predictProcessCovariance(const double dt);

  bool applyCorrection(unsigned char idx_delaystate, const ErrorState & res_delayed, double fuzzythres = 0.1);

  void propPToIdx(unsigned char idx);

  void imuCallback(const Eigen::Vector3d &linear_acceleration, const Eigen::Vector3d &angular_velocity, const double time_stamp);

  void measurementCallback(const Eigen::Vector3d &p, const Eigen::Quaterniond &q, double time_stamp);
  bool getRealPose(Vector3d &pos, Quaterniond &q);

  double getMedian(const Eigen::Matrix<double, nBuff_, 1> & data);

public:

  template<class H_type, class Res_type, class R_type>
    bool applyMeasurement(unsigned char idx_delaystate, const Eigen::MatrixBase<H_type>& H_delayed,
                          const Eigen::MatrixBase<Res_type> & res_delayed, const Eigen::MatrixBase<R_type>& R_delayed,
                          double fuzzythres = 0.1)
    {
      EIGEN_STATIC_ASSERT_FIXED_SIZE(H_type);
      EIGEN_STATIC_ASSERT_FIXED_SIZE(R_type);

      // get measurements
      if (!predictionMade_)
        return false;

      // make sure we have correctly propagated cov until idx_delaystate
      propPToIdx(idx_delaystate);

      R_type S;
      Eigen::Matrix<double, N_STATE, R_type::RowsAtCompileTime> K;
      ErrorStateCov & P = StateBuffer_[idx_delaystate].P_;

      S = H_delayed * StateBuffer_[idx_delaystate].P_ * H_delayed.transpose() + R_delayed;
      K = P * H_delayed.transpose() * S.inverse();

      correction_ = K * res_delayed;
      const ErrorStateCov KH = (ErrorStateCov::Identity() - K * H_delayed);
      P = KH * P * KH.transpose() + K * R_delayed * K.transpose();

      // make sure P stays symmetric
      P = 0.5 * (P + P.transpose());

      return applyCorrection(idx_delaystate, correction_, fuzzythres);
    }

};

#endif
