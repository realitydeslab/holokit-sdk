//
//  initial_alignment.cpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#include "initial_alignment.h"
#include "integration_base.h"
#include <iostream>

namespace AR{
    void Alignment::solveGyroscopeBias(const std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d *Bgs)
    {
        Eigen::Matrix3d A;
        Eigen::Vector3d b;
        Eigen::Vector3d delta_bg;
        A.setZero();
        b.setZero();

        for (auto frame_i = all_image_frame.begin(); next(frame_i) != all_image_frame.end(); frame_i++)
        {
            auto frame_j = next(frame_i);
            Eigen::Matrix3d tmp_A;
            tmp_A.setZero();
            Eigen::Vector3d tmp_b;
            tmp_b.setZero();
            Eigen::Quaterniond q_ij(frame_i->second.R.transpose() * frame_j->second.R);
//            std::cout<<"qij : \n"<<q_ij.toRotationMatrix()<<"\n";
            tmp_A = frame_j->second.pre_integration->jacobian.block<3, 3>(O_R, O_BG);
            tmp_b = 2 * (frame_j->second.pre_integration->delta_q.inverse() * q_ij).vec();
//            std::cout<<"pre_qij : \n"<<frame_j->second.pre_integration->delta_q.toRotationMatrix()<<"\n";

            A += tmp_A.transpose() * tmp_A;
            b += tmp_A.transpose() * tmp_b;
        }
        delta_bg = A.ldlt().solve(b);
        std::cout << "gyroscope bias initial calibration " << delta_bg.transpose() << std::endl;

        for (int i = 0; i <= WINDOW_SIZE; i++)
        {
            Bgs[i] += delta_bg;
        }

        for (auto frame_i = all_image_frame.begin(); next(frame_i) != all_image_frame.end( ); frame_i++)
        {
            auto frame_j = next(frame_i);
            frame_j->second.pre_integration->repropagate(Eigen::Vector3d::Zero(), Bgs[0]);
        }
    }

    Eigen::MatrixXd Alignment::TangentBasis(const Eigen::Vector3d &g0)
    {
        Eigen::Vector3d b, c;
        Eigen::Vector3d a = g0.normalized();
        Eigen::Vector3d tmp(0, 0, 1);
        if(a == tmp)
        {
            tmp << 1, 0, 0;
        }
        b = (tmp - a * (a.transpose() * tmp)).normalized();
        c = a.cross(b);
        Eigen::MatrixXd bc(3, 2);
        bc.block<3, 1>(0, 0) = b;
        bc.block<3, 1>(0, 1) = c;
        return bc;
    }


    void Alignment::RefineGravity(std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d &g, Eigen::VectorXd &x)
    {
        Eigen::Vector3d g0 = g.normalized() * G.norm();
        Eigen::Vector3d lx, ly;
        //VectorXd x;
        int all_frame_count = all_image_frame.size();
        int n_state = all_frame_count * 3 + 2 + 1;

        Eigen::MatrixXd A{n_state, n_state};
        A.setZero();
        Eigen::VectorXd b{n_state};
        b.setZero();

        std::map<double, AlignmentFrame>::iterator frame_i;
        std::map<double, AlignmentFrame>::iterator frame_j;
        for(int k = 0; k < 4; k++)
        {
            Eigen::MatrixXd lxly(3, 2);
            lxly = TangentBasis(g0);
            int i = 0;
            for (frame_i = all_image_frame.begin(); next(frame_i) != all_image_frame.end(); frame_i++, i++)
            {
                frame_j = next(frame_i);

                Eigen::MatrixXd tmp_A(6, 9);
                tmp_A.setZero();
                Eigen::VectorXd tmp_b(6);
                tmp_b.setZero();

                double dt = frame_j->second.pre_integration->sum_dt;


                tmp_A.block<3, 3>(0, 0) = -dt * Eigen::Matrix3d::Identity();
                tmp_A.block<3, 2>(0, 6) = frame_i->second.R.transpose() * dt * dt / 2 * Eigen::Matrix3d::Identity() * lxly;
                tmp_A.block<3, 1>(0, 8) = frame_i->second.R.transpose() * (frame_j->second.T - frame_i->second.T) / 100.0;
                tmp_b.block<3, 1>(0, 0) = frame_j->second.pre_integration->delta_p + frame_i->second.R.transpose() * frame_j->second.R *
                        TIC.block<3,1>(0,3) - TIC.block<3,1>(0,3) - frame_i->second.R.transpose() * dt * dt / 2 * g0;

                tmp_A.block<3, 3>(3, 0) = - Eigen::Matrix3d::Identity();
                tmp_A.block<3, 3>(3, 3) = frame_i->second.R.transpose() * frame_j->second.R;
                tmp_A.block<3, 2>(3, 6) = frame_i->second.R.transpose() * dt * Eigen::Matrix3d::Identity() * lxly;
                tmp_b.block<3, 1>(3, 0) = frame_j->second.pre_integration->delta_v - frame_i->second.R.transpose() * dt * Eigen::Matrix3d::Identity() * g0;


                Eigen::Matrix<double, 6, 6> cov_inv = Eigen::Matrix<double, 6, 6>::Zero();
                //cov.block<6, 6>(0, 0) = IMU_cov[i + 1];
                //MatrixXd cov_inv = cov.inverse();
                cov_inv.setIdentity();

                Eigen::MatrixXd r_A = tmp_A.transpose() * cov_inv * tmp_A;
                Eigen::VectorXd r_b = tmp_A.transpose() * cov_inv * tmp_b;

                A.block<6, 6>(i * 3, i * 3) += r_A.topLeftCorner<6, 6>();
                b.segment<6>(i * 3) += r_b.head<6>();

                A.bottomRightCorner<3, 3>() += r_A.bottomRightCorner<3, 3>();
                b.tail<3>() += r_b.tail<3>();

                A.block<6, 3>(i * 3, n_state - 3) += r_A.topRightCorner<6, 3>();
                A.block<3, 6>(n_state - 3, i * 3) += r_A.bottomLeftCorner<3, 6>();
            }
            A = A * 1000.0;
            b = b * 1000.0;
            x = A.ldlt().solve(b);
            Eigen::VectorXd dg = x.segment<2>(n_state - 3);
            g0 = (g0 + lxly * dg).normalized() * G.norm();
            //double s = x(n_state - 1);
        }
        g = g0;
    }

    bool Alignment::LinearAlignment(std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d &g, Eigen::VectorXd &x)
    {
        int all_frame_count = all_image_frame.size();
        int n_state = all_frame_count * 3 + 3 + 1;

        Eigen::MatrixXd A{n_state, n_state};
        A.setZero();
        Eigen::VectorXd b{n_state};
        b.setZero();

        std::map<double, AlignmentFrame>::iterator frame_i;
        std::map<double, AlignmentFrame>::iterator frame_j;
        int i = 0;
        for (frame_i = all_image_frame.begin(); next(frame_i) != all_image_frame.end(); frame_i++, i++)
        {
            frame_j = next(frame_i);

            Eigen::MatrixXd tmp_A(6, 10);
            tmp_A.setZero();
            Eigen::VectorXd tmp_b(6);
            tmp_b.setZero();

            double dt = frame_j->second.pre_integration->sum_dt;

            tmp_A.block<3, 3>(0, 0) = -dt * Eigen::Matrix3d::Identity();
            tmp_A.block<3, 3>(0, 6) = frame_i->second.R.transpose() * dt * dt / 2 * Eigen::Matrix3d::Identity();
            tmp_A.block<3, 1>(0, 9) = frame_i->second.R.transpose() * (frame_j->second.T - frame_i->second.T) / 100.0;
            tmp_b.block<3, 1>(0, 0) = frame_j->second.pre_integration->delta_p +
                    frame_i->second.R.transpose() * frame_j->second.R * TIC.block<3,1>(0,3) - TIC.block<3,1>(0,3);
            //cout << "delta_p   " << frame_j->second.pre_integration->delta_p.transpose() << endl;
            tmp_A.block<3, 3>(3, 0) = -Eigen::Matrix3d::Identity();
            tmp_A.block<3, 3>(3, 3) = frame_i->second.R.transpose() * frame_j->second.R;
            tmp_A.block<3, 3>(3, 6) = frame_i->second.R.transpose() * dt * Eigen::Matrix3d::Identity();
            tmp_b.block<3, 1>(3, 0) = frame_j->second.pre_integration->delta_v;
            //cout << "delta_v   " << frame_j->second.pre_integration->delta_v.transpose() << endl;

            Eigen::Matrix<double, 6, 6> cov_inv = Eigen::Matrix<double, 6, 6>::Zero();
            //cov.block<6, 6>(0, 0) = IMU_cov[i + 1];
            //MatrixXd cov_inv = cov.inverse();
            cov_inv.setIdentity();

            Eigen::MatrixXd r_A = tmp_A.transpose() * cov_inv * tmp_A;
            Eigen::VectorXd r_b = tmp_A.transpose() * cov_inv * tmp_b;

            A.block<6, 6>(i * 3, i * 3) += r_A.topLeftCorner<6, 6>();
            b.segment<6>(i * 3) += r_b.head<6>();

            A.bottomRightCorner<4, 4>() += r_A.bottomRightCorner<4, 4>();
            b.tail<4>() += r_b.tail<4>();

            A.block<6, 4>(i * 3, n_state - 4) += r_A.topRightCorner<6, 4>();
            A.block<4, 6>(n_state - 4, i * 3) += r_A.bottomLeftCorner<4, 6>();
        }
        A = A * 1000.0;
        b = b * 1000.0;
        x = A.ldlt().solve(b);
        double s = x(n_state - 1) / 100.0;
        g = x.segment<3>(n_state - 4);
        std::cout << "scale " << s << std::endl << "g " << g.transpose() <<" "<<g.norm()<< std::endl;

        if(fabs(g.norm() - G.norm()) > 1.0 || s < 0)
        {
            return false;
        }

        RefineGravity(all_image_frame, g, x);
        s = (x.tail<1>())(0) / 100.0;
        (x.tail<1>())(0) = s;
        std::cout << "refine scale " << s << std::endl << "g " << g.transpose() <<" "<<g.norm() << std::endl;
        if(s < 0.0 )
            return false;
        else
            return true;
    }

    bool Alignment::VisualIMUAlignment(std::map<double, AlignmentFrame> &all_image_frame,
            Eigen::Vector3d* Bgs, Eigen::Vector3d &g, Eigen::VectorXd &x)
    {
        solveGyroscopeBias(all_image_frame, Bgs);

        if(LinearAlignment(all_image_frame, g, x))
            return true;
        else
            return false;
    }





} // namespace AR