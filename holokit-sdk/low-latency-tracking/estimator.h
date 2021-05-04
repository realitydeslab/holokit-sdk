//
//  estimator.hpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef estimator_h
#define estimator_h

#include <Eigen/Dense>
#include "util.h"
#include "integration_base.h"
#include "marginalization_factor.h"
#include "initial_alignment.h"
namespace AR
{
    class Estimator
    {

    public:
        Estimator();

        ~Estimator();

        void setParameter();
        void clearState();


        void processIMU(double t, const Eigen::Vector3d &linear_acceleration, const Eigen::Vector3d &angular_velocity);

        void processARkit(const ARkitData & cur_arkit_data);

    private:

        bool CalibEx(const Eigen::Matrix3d & delta_R_cam,const Eigen::Quaterniond & delta_q_imu);

        bool initialStateAlignment();

        void slideWindow();

        void optimization(double timestamp);

        void vector2double();

        void double2vector();

    public:
        enum SolverFlag {
            INITIAL,
            NON_LINEAR
        };

        Eigen::Vector3d Ps[WINDOW_SIZE + 1];
        Eigen::Vector3d Vs[WINDOW_SIZE + 1];
        Eigen::Matrix3d Rs[WINDOW_SIZE + 1];
        Eigen::Vector3d Bas[WINDOW_SIZE + 1];
        Eigen::Vector3d Bgs[WINDOW_SIZE + 1];
        double Headers[WINDOW_SIZE + 1];
        ARkitData ARkit_Info[WINDOW_SIZE + 1];

        IntegrationBase *pre_integrations[WINDOW_SIZE + 1];

        Eigen::Matrix3d ric;
        Eigen::Vector3d tic;

        SolverFlag solver_flag;
        Eigen::Vector3d acc_0, gyr_0;
        Eigen::Matrix4d Tnew_old; //arkit wolrd frame change
        Eigen::Vector3d g;

    private:

        IntegrationBase *tmp_pre_integration;
        MarginalizationInfo *last_marginalization_info;
        std::vector<double *> last_marginalization_parameter_blocks;
        bool first_imu;
        int frame_count;

        std::vector<double> dt_buf[WINDOW_SIZE + 1];
        std::vector<Eigen::Vector3d> linear_acceleration_buf[WINDOW_SIZE + 1];
        std::vector<Eigen::Vector3d> angular_velocity_buf[WINDOW_SIZE + 1];

        Eigen::Matrix3d last_R, last_R0;
        Eigen::Vector3d last_P, last_P0;

        bool failure_occur;

        std::map<double, AlignmentFrame> all_ARkit_frame; //use to compute init state
        Alignment* initial_alignment;

        std::vector< Eigen::Matrix3d > Rc;
        std::vector< Eigen::Matrix3d > Rimu;
        std::vector<  Eigen::Matrix3d > Rc_g;
        Eigen::Matrix3d Guess_Ric;
        int calibr_frame_count;
        ARkitData Last_arkit_data;

        double para_Pose_R[WINDOW_SIZE + 1][SIZE_POSE_R];
        double para_Pose_T[WINDOW_SIZE + 1][SIZE_POSE_T];
        double para_Speed[WINDOW_SIZE + 1][SIZE_SPEED];
        double para_Bas[WINDOW_SIZE + 1][SIZE_BIAS_ACC];
        double para_Bgs[WINDOW_SIZE + 1][SIZE_BIAS_GYR];
        double para_Ex_Pose_R[1][SIZE_POSE_R];
        double para_Ex_Pose_T[1][SIZE_POSE_T];

    };
}


#endif /* estimator_hpp */
