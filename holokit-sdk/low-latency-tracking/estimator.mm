//
// Created by wya on 2020/11/19.
//

#include "estimator.h"
#include "factor.h"
#include "pose_local_parameterization.h"
namespace AR
{
    bool b_CalibEx = true;
    Estimator::Estimator()
    {
        for (int i = 0; i < WINDOW_SIZE + 1; i++)
        {
            pre_integrations[i] = nullptr;
        }

        for(auto &it : all_ARkit_frame)
        {
            it.second.pre_integration = nullptr;
        }

        tmp_pre_integration = nullptr;
        last_marginalization_info = nullptr;
        clearState();
    }

    Estimator::~Estimator()
    {
    }


    void Estimator::setParameter()
    {
        tic = TIC.block<3,1>(0,3);
        ric = TIC.block<3,3>(0,0);
        for (int i = 0; i < WINDOW_SIZE + 1; i++)
        {
            Bas[i] = ACC_BIAS;
            Bgs[i] = GYR_BIAS;
        }
        g << 0.0, 0.0, 0.0;
    }

    void Estimator::clearState()
    {
        initial_alignment = new Alignment();

        for (int i = 0; i < WINDOW_SIZE + 1; i++)
        {
            Rs[i].setIdentity();
            Ps[i].setZero();
            Vs[i].setZero();
            Bas[i].setZero();
            Bgs[i].setZero();
            dt_buf[i].clear();
            linear_acceleration_buf[i].clear();
            angular_velocity_buf[i].clear();

            if (pre_integrations[i] != nullptr)
                delete pre_integrations[i];
            pre_integrations[i] = nullptr;
        }

        tic = Eigen::Vector3d::Zero();
        ric = Eigen::Matrix3d::Identity();

        for(auto &it : all_ARkit_frame)
        {
            if(it.second.pre_integration != nullptr)
            {
                delete it.second.pre_integration;
            }
            it.second.pre_integration = nullptr;
        }

        if (tmp_pre_integration != nullptr)
        {
            delete tmp_pre_integration;
        }
        if (last_marginalization_info != nullptr)
        {
            delete last_marginalization_info;
        }


        tmp_pre_integration = nullptr;
        last_marginalization_info = nullptr;


        solver_flag = INITIAL;
        first_imu = false;
        frame_count = 0;


        last_marginalization_parameter_blocks.clear();
        calibr_frame_count = 0;
        Rc.push_back(Eigen::Matrix3d::Identity());
        Rc_g.push_back(Eigen::Matrix3d::Identity());
        Rimu.push_back(Eigen::Matrix3d::Identity());
        Guess_Ric = Eigen::Matrix3d::Identity();
        failure_occur = false;

        setParameter();
    }

    void Estimator::processIMU(double dt, const Eigen::Vector3d &linear_acceleration, const Eigen::Vector3d &angular_velocity)
    {
        if (!first_imu)
        {
            first_imu = true;
            acc_0 = linear_acceleration;
            gyr_0 = angular_velocity;
        }

        if (!pre_integrations[frame_count])
        {
            pre_integrations[frame_count] = new IntegrationBase{acc_0, gyr_0, Bas[frame_count], Bgs[frame_count]};
        }
        if (frame_count != 0)
        {

            pre_integrations[frame_count]->push_back(dt, linear_acceleration, angular_velocity);

            if(solver_flag == INITIAL)
            {
                tmp_pre_integration->push_back(dt, linear_acceleration, angular_velocity);
            }

            dt_buf[frame_count].push_back(dt);
            linear_acceleration_buf[frame_count].push_back(linear_acceleration);
            angular_velocity_buf[frame_count].push_back(angular_velocity);

            int j = frame_count;
            Eigen::Vector3d un_acc_0 = Rs[j] * (acc_0 - Bas[j]) - g;
            Eigen::Vector3d un_gyr = 0.5 * (gyr_0 + angular_velocity) - Bgs[j];
            Rs[j] *= deltaQ(un_gyr * dt).toRotationMatrix();
            Eigen::Vector3d un_acc_1 = Rs[j] * (linear_acceleration - Bas[j]) - g;
            Eigen::Vector3d un_acc = 0.5 * (un_acc_0 + un_acc_1);
            Ps[j] += dt * Vs[j] + 0.5 * dt * dt * un_acc;
            Vs[j] += dt * un_acc;
        }
        acc_0 = linear_acceleration;
        gyr_0 = angular_velocity;
    }


    bool Estimator::CalibEx(const Eigen::Matrix3d & delta_R_cam,const Eigen::Quaterniond & delta_q_imu)
    {
        //calib
        calibr_frame_count++;
        Rc.push_back(delta_R_cam);
        Rimu.push_back(delta_q_imu.toRotationMatrix());
        Rc_g.push_back(Guess_Ric.inverse() * delta_q_imu * Guess_Ric);

        Eigen::MatrixXd A(calibr_frame_count * 4, 4);
        A.setZero();
        int sum_ok = 0;
        for (int i = 1; i <= calibr_frame_count; i++)
        {
            Eigen::Quaterniond r1(Rc[i]);
            Eigen::Quaterniond r2(Rc_g[i]);
            double angular_distance = 180 / M_PI * r1.angularDistance(r2);
            double huber = angular_distance > 5.0 ? 5.0 / angular_distance : 1.0;
            ++sum_ok;
            Eigen::Matrix4d L, R;

            double w = Eigen::Quaterniond(Rc[i]).w();
            Eigen::Vector3d q = Eigen::Quaterniond(Rc[i]).vec();
            L.block<3, 3>(0, 0) = w * Eigen::Matrix3d::Identity() + skewSymmetric(q);
            L.block<3, 1>(0, 3) = q;
            L.block<1, 3>(3, 0) = -q.transpose();
            L(3, 3) = w;


            Eigen::Quaterniond R_ij(Rimu[i]);
            w = R_ij.w();
            q = R_ij.vec();
            R.block<3, 3>(0, 0) = w * Eigen::Matrix3d::Identity() - skewSymmetric(q);
            R.block<3, 1>(0, 3) = q;
            R.block<1, 3>(3, 0) = -q.transpose();
            R(3, 3) = w;
            A.block<4, 4>((i - 1) * 4, 0) = huber * (L - R);
        }

        Eigen::JacobiSVD< Eigen::MatrixXd> svd(A,  Eigen::ComputeFullU |  Eigen::ComputeFullV);
        Eigen::Matrix<double, 4, 1> x = svd.matrixV().col(3);
        Eigen::Quaterniond estimated_R(x);
        Guess_Ric = estimated_R.toRotationMatrix().inverse();
        Eigen::Vector3d ric_cov;
        ric_cov = svd.singularValues().tail<3>();
        std::cout<<" ric_cov(1) : " << ric_cov(1)<<"\n";

        std::cout<<"Guess_Ric \n : " << Guess_Ric<<"\n";
        std::cout << "\n\n";
        if (calibr_frame_count >= WINDOW_SIZE && ric_cov(1) > 0.25)
        {
            return true;
        } else
            return false;


    }

    void Estimator::processARkit(const ARkitData & cur_arkit_data)
    {
        double timestamp = cur_arkit_data.event_timestamp;
        Headers[frame_count] = timestamp;
        ARkit_Info[frame_count] = cur_arkit_data;
        if(!b_CalibEx)
        {
            if (frame_count != 0)
            {
                if (CalibEx(GetArkitpose(Last_arkit_data).block<3,3>(0,0).transpose() *
                            GetArkitpose(cur_arkit_data).block<3,3>(0,0),
                            pre_integrations[frame_count]->delta_q))
                {
                    b_CalibEx = true;
                }
            }
            Last_arkit_data = cur_arkit_data;
        }
        if (solver_flag == INITIAL)
        {
            AlignmentFrame alignment_frame(cur_arkit_data);
            alignment_frame.pre_integration = tmp_pre_integration;

            all_ARkit_frame.insert(std::make_pair(timestamp, alignment_frame));
            // 构造新的预积分
            tmp_pre_integration = new IntegrationBase{ acc_0, gyr_0, Bas[frame_count], Bgs[frame_count] };

            if (frame_count == WINDOW_SIZE) //Try to solve the initial state
            {
                bool result = false;
                if(b_CalibEx)
                    result = initialStateAlignment(); //初始化
                if(result)
                {
                    optimization(timestamp);
                    solver_flag = NON_LINEAR;
                    slideWindow();

                    last_R = Rs[WINDOW_SIZE];
                    last_P = Ps[WINDOW_SIZE];
                    last_R0 = Rs[0];
                    last_P0 = Ps[0];
                    LOG(WARNING) << "Initialized!";

                }
                else
                {
                    slideWindow();
                }
            }
            else
            {
                frame_count++;
            }
        }
        else
        {

            optimization(timestamp);
            slideWindow();

            last_R = Rs[WINDOW_SIZE];
            last_P = Ps[WINDOW_SIZE];
            last_R0 = Rs[0];
            last_P0 = Ps[0];
        }

    }
    void Estimator::vector2double()
    {



        for (int i = 0; i <= WINDOW_SIZE; i++)
        {

            Eigen::Matrix4d TWc = GetArkitpose(ARkit_Info[i]);
            Eigen::Matrix4d new_TWb = Tnew_old * TWc * TCI;
//            para_Pose_T[i][0] = Ps[i].x();
//            para_Pose_T[i][1] = Ps[i].y();
//            para_Pose_T[i][2] = Ps[i].z();
//
//            Eigen::Quaterniond q{Rs[i]};
//            para_Pose_R[i][0] = q.x();
//            para_Pose_R[i][1] = q.y();
//            para_Pose_R[i][2] = q.z();
//            para_Pose_R[i][3] = q.w();

            para_Pose_T[i][0] = new_TWb(0,3);
            para_Pose_T[i][1] = new_TWb(1,3);
            para_Pose_T[i][2] = new_TWb(2,3);

            Eigen::Quaterniond q{new_TWb.block<3,3>(0,0)};
            para_Pose_R[i][0] = q.x();
            para_Pose_R[i][1] = q.y();
            para_Pose_R[i][2] = q.z();
            para_Pose_R[i][3] = q.w();

            para_Speed[i][0] = Vs[i].x();
            para_Speed[i][1] = Vs[i].y();
            para_Speed[i][2] = Vs[i].z();


            para_Bas[i][0] = Bas[i].x();
            para_Bas[i][1] = Bas[i].y();
            para_Bas[i][2] = Bas[i].z();

            para_Bgs[i][0] = Bgs[i].x();
            para_Bgs[i][1] = Bgs[i].y();
            para_Bgs[i][2] = Bgs[i].z();

        }
        para_Ex_Pose_T[0][0] = tic.x();
        para_Ex_Pose_T[0][1] = tic.y();
        para_Ex_Pose_T[0][2] = tic.z();

        Eigen::Quaterniond q{ric};
        para_Ex_Pose_R[0][0] = q.x();
        para_Ex_Pose_R[0][1] = q.y();
        para_Ex_Pose_R[0][2] = q.z();
        para_Ex_Pose_R[0][3] = q.w();

    }

    void Estimator::double2vector()
    {
        Eigen::Vector3d origin_R0 = R2ypr(Rs[0]);
        Eigen::Vector3d origin_P0 = Ps[0];

        if (failure_occur)
        {
            origin_R0 = R2ypr(last_R0);
            origin_P0 = last_P0;
            failure_occur = 0;
        }
        Eigen::Vector3d origin_R00 = R2ypr(Eigen::Quaterniond(para_Pose_R[0][3],
                                                                       para_Pose_R[0][0],
                                                                       para_Pose_R[0][1],
                                                                       para_Pose_R[0][2]).toRotationMatrix());
        double y_diff = origin_R0.x() - origin_R00.x();
        //TODO
        Eigen::Matrix3d rot_diff = ypr2R(Eigen::Vector3d(y_diff, 0, 0));
        if (abs(abs(origin_R0.y()) - 90) < 1.0 || abs(abs(origin_R00.y()) - 90) < 1.0)
        {
            rot_diff = Rs[0] * Eigen::Quaterniond(para_Pose_R[0][3],
                                                  para_Pose_R[0][0],
                                                  para_Pose_R[0][1],
                                                  para_Pose_R[0][2]).toRotationMatrix().transpose();
        }

        for (int i = 0; i <= WINDOW_SIZE; i++)
        {
            Rs[i] = rot_diff * Eigen::Quaterniond(para_Pose_R[i][3], para_Pose_R[i][0], para_Pose_R[i][1], para_Pose_R[i][2]).normalized().toRotationMatrix();

            Ps[i] = rot_diff * Eigen::Vector3d(para_Pose_T[i][0] - para_Pose_T[0][0],
                                               para_Pose_T[i][1] - para_Pose_T[0][1],
                                               para_Pose_T[i][2] - para_Pose_T[0][2]) + origin_P0;

            Vs[i] = rot_diff * Eigen::Vector3d(para_Speed[i][0],
                                               para_Speed[i][1],
                                               para_Speed[i][2]);

            Bas[i] = Eigen::Vector3d(para_Bas[i][0],
                                     para_Bas[i][1],
                                     para_Bas[i][2]);

            Bgs[i] = Eigen::Vector3d(para_Bgs[i][0],
                                     para_Bgs[i][1],
                                     para_Bgs[i][2]);
        }

        tic = Eigen::Vector3d(para_Ex_Pose_T[0][0],
                              para_Ex_Pose_T[0][1],
                              para_Ex_Pose_T[0][2]);
        ric = Eigen::Quaterniond(para_Ex_Pose_R[0][3],
                                 para_Ex_Pose_R[0][0],
                                 para_Ex_Pose_R[0][1],
                                 para_Ex_Pose_R[0][2]).toRotationMatrix();
    }



    void Estimator::optimization(double timestamp)
    {
        vector2double();

        ceres::Problem::Options options_for_problem;

        ceres::Problem problem;
        ceres::LossFunction *loss_function;
        loss_function = new ceres::TukeyLoss(20.0);
//        loss_function = new ceres::CauchyLoss(1.0);

        for (int i = 0; i <= WINDOW_SIZE; i++)
        {
            ceres::LocalParameterization *local_parameterization = new PoseLocalParameterization();
            problem.AddParameterBlock(para_Pose_R[i], SIZE_POSE_R, local_parameterization);
            problem.AddParameterBlock(para_Pose_T[i], SIZE_POSE_T);
            problem.AddParameterBlock(para_Speed[i], SIZE_SPEED);
            problem.AddParameterBlock(para_Bas[i], SIZE_BIAS_ACC);
            problem.AddParameterBlock(para_Bgs[i], SIZE_BIAS_GYR);

        }

        {
            ceres::LocalParameterization *local_parameterization = new PoseLocalParameterization();
            problem.AddParameterBlock(para_Ex_Pose_R[0], SIZE_POSE_R, local_parameterization);
            problem.AddParameterBlock(para_Ex_Pose_T[0], SIZE_POSE_T);
            if (!ESTIMATE_EXTRINSIC)
            {
                problem.SetParameterBlockConstant(para_Ex_Pose_R[0]);
                problem.SetParameterBlockConstant(para_Ex_Pose_T[0]);
            }
        }

        double dMarginResidual = 0.0;
        if (last_marginalization_info)
        {
            // construct new marginlization_factor
            MarginalizationFactor *marginalization_factor = new MarginalizationFactor(last_marginalization_info);
            problem.AddResidualBlock(marginalization_factor, NULL, last_marginalization_parameter_blocks);
//            problem.Evaluate(ceres::Problem::EvaluateOptions(), &dMarginResidual, NULL, NULL, NULL);
        }

//        LOG(WARNING)<<"$RSD margin " << std::setprecision(std::numeric_limits<double>::max_digits10) <<timestamp<<" "<<dMarginResidual;

        double dIMUResidual = 0.0;
        for (int i = 0; i < WINDOW_SIZE; i++)
        {
            int j = i + 1;
            if (pre_integrations[j]->sum_dt > 10.0)
            {
                continue;
            }
            if(pre_integrations[j]->acc_buf.empty() || pre_integrations[j]->gyr_buf.empty())
            {
                LOG(WARNING) << "ACC&GYR Loss in estimator!";
                continue;
            }

            IMUFactor* imu_factor = new IMUFactor(pre_integrations[j]);
            problem.AddResidualBlock(imu_factor, NULL, para_Pose_T[i], para_Pose_R[i], para_Speed[i], para_Bas[i], para_Bgs[i], para_Pose_T[j], para_Pose_R[j], para_Speed[j], para_Bas[j], para_Bgs[j]);

//            double *para[10];
//            para[0] = para_Pose_T[i];
//            para[1] = para_Pose_R[i];
//            para[2] = para_Speed[i];
//            para[3] = para_Bas[i];
//            para[4] = para_Bgs[i];
//            para[5] = para_Pose_T[j];
//            para[6] = para_Pose_R[j];
//            para[7] = para_Speed[j];
//            para[8] = para_Bas[j];
//            para[9] = para_Bgs[j];
//
//            double res[15];
//            imu_factor->Evaluate(para, res, NULL);
//
//            Eigen::Map<Eigen::Matrix<double, 15, 1>> residual(res);
//            dIMUResidual += 0.5 * residual.transpose().dot(residual);
        }
//        LOG(WARNING)<<"$RSD imu "<< std::setprecision(std::numeric_limits<double>::max_digits10) << timestamp <<" "<<dIMUResidual;
//        std::cout<<"$RSD imu "<< std::setprecision(std::numeric_limits<double>::max_digits10) << timestamp <<" "<<dIMUResidual<<"\n";



        double rot_scale = 0.0001;
        double rot_cov_rad = sin(1 * PI /180);

        Eigen::Vector3d rot_cov = {rot_cov_rad , rot_cov_rad ,rot_cov_rad};
        rot_cov *= rot_scale;
        double trans_cov_m = rot_scale * 0.03;

        Eigen::Vector3d trans_cov = {trans_cov_m , trans_cov_m ,trans_cov_m};
        double dARkitResidual = 0.0;

        for (int k = 0; k <=  WINDOW_SIZE; ++k)
        {

            Eigen::Matrix4d TWc = GetArkitpose(ARkit_Info[k]);
            Eigen::Matrix4d new_TWb = Tnew_old * TWc * TCI;
            ARkitFactor * ARKit_factor = new ARkitFactor(new_TWb, trans_cov, rot_cov);
            problem.AddResidualBlock(ARKit_factor, NULL, para_Pose_T[k], para_Pose_R[k]);
        }


        ceres::Solver::Options options;


        options.linear_solver_type = ceres::DENSE_NORMAL_CHOLESKY;
        //options.num_threads = 2;
        options.trust_region_strategy_type = ceres::LEVENBERG_MARQUARDT;
        options.max_num_iterations = 15;
        options.max_solver_time_in_seconds = 0.1;
        options.minimizer_progress_to_stdout = false;

//        LOG(WARNING) << "$CostFunctionCount: " << problem.NumResidualBlocks();
        ceres::Solver::Summary summary;
        ceres::Solve(options, &problem, &summary);
        double final_cost = summary.final_cost;


        double2vector();

        std::cout<<"acc bais:"<<Bas[WINDOW_SIZE].transpose()<<"\n";
        std::cout<<"gyr bais:"<<Bgs[WINDOW_SIZE].transpose()<<"\n";

        MarginalizationInfo *marginalization_info = new MarginalizationInfo();
        vector2double();

        if (last_marginalization_info)
        {
            std::vector<int> drop_set;
            for (int i = 0; i < static_cast<int>(last_marginalization_parameter_blocks.size()); i++)
            {
                if (last_marginalization_parameter_blocks[i] == para_Pose_T[0] ||
                    last_marginalization_parameter_blocks[i] == para_Pose_R[0] ||
                    last_marginalization_parameter_blocks[i] == para_Speed[0] ||
                    last_marginalization_parameter_blocks[i] == para_Bas[0] ||
                    last_marginalization_parameter_blocks[i] == para_Bgs[0])
                {
                    drop_set.push_back(i);
                }
            }
            // construct new marginlization_factor
            MarginalizationFactor *marginalization_factor = new MarginalizationFactor(last_marginalization_info);
            ResidualBlockInfo *residual_block_info = new ResidualBlockInfo(marginalization_factor,
                                                                           NULL,
                                                                           last_marginalization_parameter_blocks,
                                                                           drop_set);
            marginalization_info->addResidualBlockInfo(residual_block_info);
        }

        {
            if (pre_integrations[1]->sum_dt < 10.0)
            {
                IMUFactor* imu_factor = new IMUFactor(pre_integrations[1]);
                ResidualBlockInfo *residual_block_info = new ResidualBlockInfo(imu_factor,
                                                                               NULL,
                                                                               std::vector<double *>{para_Pose_T[0], para_Pose_R[0], para_Speed[0], para_Bas[0], para_Bgs[0], para_Pose_T[1], para_Pose_R[1], para_Speed[1], para_Bas[1], para_Bgs[1]},
                                                                               std::vector<int>{0, 1, 2, 3, 4});
                marginalization_info->addResidualBlockInfo(residual_block_info);
            }
        }

        {
            Eigen::Matrix4d TWc = GetArkitpose(ARkit_Info[0]);
            Eigen::Matrix4d new_TWc = Tnew_old * TWc * TCI;
            ARkitFactor * ARKit_factor = new ARkitFactor(new_TWc,trans_cov,rot_cov);

            ResidualBlockInfo *residual_block_info = new ResidualBlockInfo(ARKit_factor,
                                                                           loss_function,
                                                                           std::vector<double *>{para_Pose_T[0], para_Pose_R[0]},
                                                                           std::vector<int>{0, 1});
            marginalization_info->addResidualBlockInfo(residual_block_info);

        }

        marginalization_info->preMarginalize();
        marginalization_info->marginalize();

        std::unordered_map<long, double *> addr_shift;
        for (int i = 1; i <= WINDOW_SIZE; i++)
        {
            addr_shift[reinterpret_cast<long>(para_Pose_T[i])] = para_Pose_T[i - 1];
            addr_shift[reinterpret_cast<long>(para_Pose_R[i])] = para_Pose_R[i - 1];
            addr_shift[reinterpret_cast<long>(para_Speed[i])] = para_Speed[i - 1];
            addr_shift[reinterpret_cast<long>(para_Bas[i])] = para_Bas[i - 1];
            addr_shift[reinterpret_cast<long>(para_Bgs[i])] = para_Bgs[i - 1];
        }
        addr_shift[reinterpret_cast<long>(para_Ex_Pose_T[0])] = para_Ex_Pose_T[0];
        addr_shift[reinterpret_cast<long>(para_Ex_Pose_R[0])] = para_Ex_Pose_R[0];

        last_marginalization_info = marginalization_info;
        last_marginalization_parameter_blocks = marginalization_info->getParameterBlocks(addr_shift);

    }




    void Estimator::slideWindow()
    {
        double t_0 = Headers[0];

        if (frame_count == WINDOW_SIZE)
        {
            for (int i = 0; i < WINDOW_SIZE; i++)
            {
                Rs[i].swap(Rs[i + 1]);

                std::swap(pre_integrations[i], pre_integrations[i + 1]);

                dt_buf[i].swap(dt_buf[i + 1]);
                linear_acceleration_buf[i].swap(linear_acceleration_buf[i + 1]);
                angular_velocity_buf[i].swap(angular_velocity_buf[i + 1]);

                Headers[i] = Headers[i + 1];
                ARkit_Info[i] = ARkit_Info[i + 1];

                Ps[i].swap(Ps[i + 1]);
                Vs[i].swap(Vs[i + 1]);
                Bas[i].swap(Bas[i + 1]);
                Bgs[i].swap(Bgs[i + 1]);
            }
            Headers[WINDOW_SIZE] = Headers[WINDOW_SIZE - 1];
            Ps[WINDOW_SIZE] = Ps[WINDOW_SIZE - 1];
            Vs[WINDOW_SIZE] = Vs[WINDOW_SIZE - 1];
            Rs[WINDOW_SIZE] = Rs[WINDOW_SIZE - 1];
            Bas[WINDOW_SIZE] = Bas[WINDOW_SIZE - 1];
            Bgs[WINDOW_SIZE] = Bgs[WINDOW_SIZE - 1];

            ARkit_Info[WINDOW_SIZE] = ARkit_Info[WINDOW_SIZE - 1];

            delete pre_integrations[WINDOW_SIZE];
            pre_integrations[WINDOW_SIZE] = new IntegrationBase{acc_0, gyr_0, Bas[WINDOW_SIZE], Bgs[WINDOW_SIZE]};

            dt_buf[WINDOW_SIZE].clear();
            linear_acceleration_buf[WINDOW_SIZE].clear();
            angular_velocity_buf[WINDOW_SIZE].clear();

            if (true || solver_flag == INITIAL)
            {
                std::map<double, AlignmentFrame>::iterator it_0;
                it_0 = all_ARkit_frame.find(t_0);
                delete it_0->second.pre_integration;
                it_0->second.pre_integration = nullptr;

                for (std::map<double, AlignmentFrame>::iterator it = all_ARkit_frame.begin(); it != it_0; ++it)
                {
                    if (it->second.pre_integration)
                        delete it->second.pre_integration;
                    it->second.pre_integration = NULL;
                }
                all_ARkit_frame.erase(all_ARkit_frame.begin(), it_0);
                all_ARkit_frame.erase(t_0);
            }
        }
    }


    bool Estimator::initialStateAlignment()
    {
        //check imu observibility
        {
            std::map<double, AlignmentFrame>::iterator frame_it;
            Eigen::Vector3d sum_g{0, 0, 0};
            for (frame_it = all_ARkit_frame.begin(), frame_it++; frame_it != all_ARkit_frame.end(); frame_it++)
            {
                double dt = frame_it->second.pre_integration->sum_dt;
                Eigen::Vector3d tmp_g = frame_it->second.pre_integration->delta_v / dt;
                sum_g += tmp_g;
            }
            Eigen::Vector3d aver_g;
            aver_g = sum_g * 1.0 / ((int)all_ARkit_frame.size() - 1);
            double var = 0;

            for (frame_it = all_ARkit_frame.begin(), frame_it++; frame_it != all_ARkit_frame.end(); frame_it++)
            {
                double dt = frame_it->second.pre_integration->sum_dt;
                Eigen::Vector3d tmp_g = frame_it->second.pre_integration->delta_v / dt;
                var += (tmp_g - aver_g).transpose() * (tmp_g - aver_g);
                //cout << "frame g " << tmp_g.transpose() << endl;
            }
            var = sqrt(var / ((int)all_ARkit_frame.size() - 1));
            // NOTE: Make var smaller when open the low-pass filter
            if(var < 0.25)
            {
                printf("IMU excitation not enough!%f\n",var);
                LOG(INFO)<<"IMU excitation not enough! "<< var;
//                return false;
            }
        }

        //transfrom pose to Tc0_bk

        std::vector<Eigen::Matrix4d> ARkit_Twc(frame_count + 1);
        Eigen::Matrix<double, 3, Eigen::Dynamic> ARkit_twb(3, frame_count+1);

        Eigen::Matrix4d Tc0_w = GetArkitpose(all_ARkit_frame.begin()->second.ARkit_data).inverse();
        {
            std::map<double, AlignmentFrame>::iterator frame_it; //dont need frame_it++
            int i = 0;
            for (frame_it = all_ARkit_frame.begin(); frame_it != all_ARkit_frame.end(); frame_it++)
            {
                Eigen::Matrix4d Twck = GetArkitpose(frame_it->second.ARkit_data);

                Eigen::Vector3d twbk = (Twck * TCI).block<3,1>(0,3);
                ARkit_twb.col(i) = twbk;
                ARkit_Twc[i++] = Twck;

                Eigen::Matrix4d Tc0_ck = Tc0_w * Twck;
                Eigen::Matrix4d Tc0_bk = Tc0_ck * TCI;
                frame_it->second.R = Tc0_bk.block<3,3>(0,0);
                frame_it->second.T = Tc0_ck.block<3,1>(0,3);
            }
        }

        Eigen::VectorXd x;

        bool result =  initial_alignment->VisualIMUAlignment(all_ARkit_frame, Bgs, g, x);
        if(!result)
        {
            std::cout<<"solve g failed!\n";
            return false;
        }

        // change state
        for (int i = 0; i <= frame_count; i++)
        {
            Eigen::Matrix3d Ri = all_ARkit_frame[Headers[i]].R;
            Eigen::Vector3d Pi = all_ARkit_frame[Headers[i]].T;
            Ps[i] = Pi;
            Rs[i] = Ri;
        }


        //Get sim3
        {
            Eigen::Vector3d c0ck = Ps[0] - Rs[0] * TIC.block<3,1>(0,3);
            std::vector<Eigen::Vector3d> Ps_(WINDOW_SIZE + 1);
            for (int i = frame_count; i >= 0; i--)
            {
                Ps_[i] = Ps[i] - Rs[i] * TIC.block<3,1>(0,3) - c0ck;
            }
            Eigen::Matrix3d R0 = g2R(g);
            double yaw = R2ypr(R0 * Rs[0]).x();
            R0 = ypr2R(Eigen::Vector3d{-yaw, 0, 0}) * R0;
            Eigen::Matrix3d rot_diff = R0;
            Eigen::Matrix<double, 3, Eigen::Dynamic> Aligned_twb(3, frame_count+1);
            for (int i = 0; i <= frame_count; i++)
            {
                Ps_[i] = rot_diff * Ps_[i];
                Aligned_twb.col(i) = Ps_[i];
            }
            Eigen::Matrix<double, 3, 4> sim3 = Eigen::umeyama(ARkit_twb, Aligned_twb, false).topLeftCorner(3, 4);
            Tnew_old = Eigen::Matrix4d::Identity();
            Tnew_old.block<3,4>(0,0) = sim3;
//            for (int i = 0; i <= frame_count; i++)
//            {
//                std::cout<< Tnew_old * ARkit_Twc[i] * TCI<<"\n";
//            }

        }
//            double s = (x.tail<1>())(0);
        double s = 1.0;
        for (int i = 0; i <= WINDOW_SIZE; i++)
        {
            pre_integrations[i]->repropagate(Eigen::Vector3d::Zero(), Bgs[i]);
        }
        for (int i = frame_count; i >= 0; i--)
            Ps[i] = s * Ps[i] - Rs[i] * TIC.block<3,1>(0,3) - (s * Ps[0] - Rs[0] * TIC.block<3,1>(0,3));

        int kv = -1;
        std::map<double, AlignmentFrame>::iterator frame_i;
        for (frame_i = all_ARkit_frame.begin(); frame_i != all_ARkit_frame.end(); frame_i++)
        {
            kv++;
            Vs[kv] = frame_i->second.R * x.segment<3>(kv * 3);
        }

        Eigen::Matrix3d R0 = g2R(g);
        double yaw = R2ypr(R0 * Rs[0]).x();
        R0 = ypr2R(Eigen::Vector3d{-yaw, 0, 0}) * R0;
        g = R0 * g;
        //Matrix3d rot_diff = R0 * Rs[0].transpose();
        Eigen::Matrix3d rot_diff = R0;
//        Eigen::Matrix<double, 3, Eigen::Dynamic> Aligned_twb(3, frame_count+1);
        for (int i = 0; i <= frame_count; i++)
        {
            Ps[i] = rot_diff * Ps[i];
            Rs[i] = rot_diff * Rs[i];
            Vs[i] = rot_diff * Vs[i];
//            std::cout<<"Ps{i}"<<Ps[i].transpose()<<"\n";
//            Aligned_twb.col(i) = Ps[i];
        }
//        Eigen::Matrix<double, 3, 4> sim3 = Eigen::umeyama(ARkit_twb, Aligned_twb, false).topLeftCorner(3, 4);
//        Tnew_old = Eigen::Matrix4d::Identity();
//        Tnew_old.block<3,4>(0,0) = sim3;

        return true;
    }



}
