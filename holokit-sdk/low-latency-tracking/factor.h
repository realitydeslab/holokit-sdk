//
//  factor.h
//  holokit
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef factor_h
#define factor_h


#include <iostream>
#include <Eigen/Dense>
#include "integration_base.h"
#include "ceres/ceres.h"

using ceres::AutoDiffCostFunction;
using ceres::CostFunction;
using ceres::Problem;
using ceres::Solve;
using ceres::Solver;


namespace AR{


    class ARkitFactor : public ceres::SizedCostFunction<6, 3, 4>
    {
    public:
        ARkitFactor() = delete;
        ARkitFactor(const Eigen::Matrix4d & T_new_wb,const Eigen::Vector3d & trans_cov_,
                const Eigen::Vector3d & rot_cov_ ): trans_cov_vec{trans_cov_},rot_cov_vec{rot_cov_}
        {
            Q_wb_ARkit = Eigen::Quaterniond(T_new_wb.block<3,3>(0, 0));
            t_wb_ARkit = T_new_wb.block<3,1>(0, 3);
        }

        virtual bool Evaluate(double const *const *parameters, double *residuals, double **jacobians) const
        {
            Eigen::Quaterniond Qwb(parameters[1][3], parameters[1][0], parameters[1][1], parameters[1][2]);

            Eigen::Vector3d twb(parameters[0][0], parameters[0][1], parameters[0][2]);

            Eigen::Map<Eigen::Matrix<double, 6, 1>> residual(residuals); //trans, rot

            Eigen::Vector3d trans_residual = (twb - t_wb_ARkit);
            for (int i = 0; i < 3; ++i)
                trans_residual / trans_cov_vec[i];

            Eigen::Vector3d rot_residual = 2 * (Q_wb_ARkit.inverse() * Qwb).vec();
            Eigen::Matrix<double, 3, 3> rot_cov = Eigen::Matrix<double, 3, 3>::Zero();
            rot_cov(0, 0) = rot_cov_vec[0] * rot_cov_vec[0];
            rot_cov(1, 1) = rot_cov_vec[1] * rot_cov_vec[1];
            rot_cov(2, 2) = rot_cov_vec[2] * rot_cov_vec[2];
            Eigen::Matrix<double, 3, 3> rot_sqrt_info = Eigen::LLT<Eigen::Matrix<double, 3, 3>>(rot_cov.inverse()).matrixL().transpose();

            rot_residual = rot_sqrt_info * rot_residual;
//            std::cout<<"rot_residual:"<<rot_residual.transpose()<<"\n";


            residual.block<3,1>(0,0) = trans_residual;
            residual.block<3,1>(3,0) = rot_residual;

//            std::cout<<"res:"<<residual.transpose()<<"\n";

            if (jacobians)
            {
                if (jacobians[0])
                {
                    Eigen::Map<Eigen::Matrix<double, 6, 3, Eigen::RowMajor>> jacobian_pose_t(jacobians[0]);
                    jacobian_pose_t.setZero();

                    jacobian_pose_t(0, 0) = 1 / trans_cov_vec[0];
                    jacobian_pose_t(1, 1) = 1 / trans_cov_vec[1];
                    jacobian_pose_t(2, 2) = 1 / trans_cov_vec[2];


                    if (jacobian_pose_t.maxCoeff() > 1e8 || jacobian_pose_t.minCoeff() < -1e8)
                    {
                        std::cout << "WARN: numerical unstable" << std::endl;

                        return false;
                    }
                }
                if (jacobians[1])
                {
                    Eigen::Map<Eigen::Matrix<double, 6, 4, Eigen::RowMajor>> jacobian_pose_r(jacobians[1]);
                    jacobian_pose_r.setZero();
                    jacobian_pose_r.block<3, 3>(O_R, 0)
                            = Qleft(Q_wb_ARkit.inverse() * Qwb).bottomRightCorner<3, 3>();

                    jacobian_pose_r.block<3, 3>(O_R, 0) = rot_sqrt_info * jacobian_pose_r.block<3, 3>(O_R, 0);

                    if (jacobian_pose_r.maxCoeff() > 1e8 || jacobian_pose_r.minCoeff() < -1e8)
                    {
                        std::cout << "WARN: numerical unstable" << std::endl;

                        return false;
                    }
                }
            }
            return true;

        }

        Eigen::Quaterniond Q_wb_ARkit;
        Eigen::Vector3d t_wb_ARkit ,trans_cov_vec,rot_cov_vec ;
    };

    class IMUFactor : public ceres::SizedCostFunction<15, 3, 4, 3, 3, 3, 3, 4, 3, 3, 3>
    {
    public:
        IMUFactor() = delete;
        IMUFactor(IntegrationBase* _pre_integration):pre_integration(_pre_integration)
        {
        }
        virtual bool Evaluate(double const *const *parameters, double *residuals, double **jacobians) const
        {

            Eigen::Vector3d Pi(parameters[0][0], parameters[0][1], parameters[0][2]);

            Eigen::Quaterniond Qi(parameters[1][3], parameters[1][0], parameters[1][1], parameters[1][2]);

            Eigen::Vector3d Vi(parameters[2][0], parameters[2][1], parameters[2][2]);

            Eigen::Vector3d Bai(parameters[3][0], parameters[3][1], parameters[3][2]);

            Eigen::Vector3d Bgi(parameters[4][0], parameters[4][1], parameters[4][2]);

            Eigen::Vector3d Pj(parameters[5][0], parameters[5][1], parameters[5][2]);

            Eigen::Quaterniond Qj(parameters[6][3], parameters[6][0], parameters[6][1], parameters[6][2]);

            Eigen::Vector3d Vj(parameters[7][0], parameters[7][1], parameters[7][2]);

            Eigen::Vector3d Baj(parameters[8][0], parameters[8][1], parameters[8][2]);

            Eigen::Vector3d Bgj(parameters[9][0], parameters[9][1], parameters[9][2]);

            Eigen::Map<Eigen::Matrix<double, 15, 1>> residual(residuals);
            residual = pre_integration->evaluate(Pi, Qi, Vi, Bai, Bgi,
                                                 Pj, Qj, Vj, Baj, Bgj);


//            std::cout<<"IMT:"<<residual.transpose()<<"\n";

            Eigen::Matrix<double, 15, 15> sqrt_info = Eigen::LLT<Eigen::Matrix<double, 15, 15>>(pre_integration->covariance.inverse()).matrixL().transpose();
            residual = sqrt_info * residual;

            if (jacobians)
            {
                double sum_dt = pre_integration->sum_dt;
                Eigen::Matrix3d dp_dba = pre_integration->jacobian.template block<3, 3>(O_P, O_BA);
                Eigen::Matrix3d dp_dbg = pre_integration->jacobian.template block<3, 3>(O_P, O_BG);

                Eigen::Matrix3d dq_dbg = pre_integration->jacobian.template block<3, 3>(O_R, O_BG);

                Eigen::Matrix3d dv_dba = pre_integration->jacobian.template block<3, 3>(O_V, O_BA);
                Eigen::Matrix3d dv_dbg = pre_integration->jacobian.template block<3, 3>(O_V, O_BG);

                if (pre_integration->jacobian.maxCoeff() > 1e8 || pre_integration->jacobian.minCoeff() < -1e8)
                {
                    printf("numerical unstable in preintegration\n");
                }

                if (jacobians[0])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_pose_i_t(jacobians[0]);
                    jacobian_pose_i_t.setZero();
                    jacobian_pose_i_t.block<3, 3>(O_P, 0) = -Qi.inverse().toRotationMatrix();
                    jacobian_pose_i_t = sqrt_info * jacobian_pose_i_t;
                }
                if (jacobians[1])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 4, Eigen::RowMajor>> jacobian_pose_i_r(jacobians[1]);
                    jacobian_pose_i_r.setZero();
                    jacobian_pose_i_r.block<3, 3>(O_P, 0) = skewSymmetric(Qi.inverse() * (0.5 * G * sum_dt * sum_dt + Pj - Pi - Vi * sum_dt));
                    Eigen::Quaterniond corrected_delta_q = pre_integration->delta_q * deltaQ(dq_dbg * (Bgi - pre_integration->linearized_bg));
                    jacobian_pose_i_r.block<3, 3>(O_R, 0) = -(Qleft(Qj.inverse() * Qi) * Qright(corrected_delta_q)).bottomRightCorner<3, 3>();
                    jacobian_pose_i_r.block<3, 3>(O_V, 0) = skewSymmetric(Qi.inverse() * (G * sum_dt + Vj - Vi));
                    jacobian_pose_i_r = sqrt_info * jacobian_pose_i_r;
                }
                if (jacobians[2])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_speed_i(jacobians[2]);
                    jacobian_speed_i.setZero();
                    jacobian_speed_i.block<3, 3>(O_P, 0) = -Qi.inverse().toRotationMatrix() * sum_dt;
                    jacobian_speed_i.block<3, 3>(O_V, 0) = -Qi.inverse().toRotationMatrix();
                    jacobian_speed_i = sqrt_info * jacobian_speed_i;
                }
                if (jacobians[3])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_bas_i(jacobians[3]);
                    jacobian_bas_i.setZero();
                    jacobian_bas_i.block<3, 3>(O_P, 0) = -dp_dba;
                    jacobian_bas_i.block<3, 3>(O_V, 0) = -dv_dba;
                    jacobian_bas_i.block<3, 3>(O_BA, 0) = -Eigen::Matrix3d::Identity();
                    jacobian_bas_i = sqrt_info * jacobian_bas_i;
                }
                if (jacobians[4])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_bgs_i(jacobians[4]);
                    jacobian_bgs_i.setZero();
                    jacobian_bgs_i.block<3, 3>(O_P, 0) = -dp_dbg;
                    jacobian_bgs_i.block<3, 3>(O_R, 0) = -Qleft(Qj.inverse() * Qi * pre_integration->delta_q).bottomRightCorner<3, 3>() * dq_dbg;
                    jacobian_bgs_i.block<3, 3>(O_V, 0) = -dv_dbg;
                    jacobian_bgs_i.block<3, 3>(O_BG, 0) = -Eigen::Matrix3d::Identity();
                    jacobian_bgs_i = sqrt_info * jacobian_bgs_i;
                }
                if (jacobians[5])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_pose_j_t(jacobians[5]);
                    jacobian_pose_j_t.setZero();
                    jacobian_pose_j_t.block<3, 3>(O_P, 0) = Qi.inverse().toRotationMatrix();
                    jacobian_pose_j_t = sqrt_info * jacobian_pose_j_t;
                }
                if (jacobians[6])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 4, Eigen::RowMajor>> jacobian_pose_j_r(jacobians[6]);
                    jacobian_pose_j_r.setZero();
                    Eigen::Quaterniond corrected_delta_q = pre_integration->delta_q * deltaQ(dq_dbg * (Bgi - pre_integration->linearized_bg));
                    jacobian_pose_j_r.block<3, 3>(O_R, 0) = Qleft(corrected_delta_q.inverse() * Qi.inverse() * Qj).bottomRightCorner<3, 3>();
                    jacobian_pose_j_r = sqrt_info * jacobian_pose_j_r;
                }
                if (jacobians[7])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_speed_j(jacobians[7]);
                    jacobian_speed_j.setZero();
                    jacobian_speed_j.block<3, 3>(O_V, 0) = Qi.inverse().toRotationMatrix();
                    jacobian_speed_j = sqrt_info * jacobian_speed_j;
                }
                if (jacobians[8])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_bas_j(jacobians[8]);
                    jacobian_bas_j.setZero();
                    jacobian_bas_j.block<3, 3>(O_BA, 0) = Eigen::Matrix3d::Identity();
                    jacobian_bas_j = sqrt_info * jacobian_bas_j;
                }
                if (jacobians[9])
                {
                    Eigen::Map<Eigen::Matrix<double, 15, 3, Eigen::RowMajor>> jacobian_bgs_j(jacobians[9]);
                    jacobian_bgs_j.setZero();
                    jacobian_bgs_j.block<3, 3>(O_BG, 0) = Eigen::Matrix3d::Identity();
                    jacobian_bgs_j = sqrt_info * jacobian_bgs_j;
                }
            }

            return true;
        }

        IntegrationBase* pre_integration;
    };


} // namespace AR



#endif /* factor_h */
