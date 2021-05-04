//
//  marginalization_factor.cpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//


#include "marginalization_factor.h"

#include <thread>

namespace AR{

    struct ThreadsStruct
    {
        std::vector<ResidualBlockInfo *> sub_factors;
        Eigen::MatrixXd A;
        Eigen::VectorXd b;
        std::unordered_map<long, int> parameter_block_size; // global size
        std::unordered_map<long, int> parameter_block_idx;  // local  size
    };


    void ResidualBlockInfo::Evaluate()
    {
        residuals.resize(cost_function->num_residuals());

        std::vector<int> block_sizes = cost_function->parameter_block_sizes();
        raw_jacobians = new double *[block_sizes.size()];
        jacobians.resize(block_sizes.size());

        for (int i = 0; i < static_cast<int>(block_sizes.size()); i++)
        {
            jacobians[i].resize(cost_function->num_residuals(), block_sizes[i]);
            raw_jacobians[i] = jacobians[i].data();
        }

        cost_function->Evaluate(parameter_blocks.data(), residuals.data(), raw_jacobians);

        if (loss_function)
        {
            double residual_scaling_, alpha_sq_norm_;

            double sq_norm, rho[3];

            sq_norm = residuals.squaredNorm();
            loss_function->Evaluate(sq_norm, rho);

            double sqrt_rho1_ = sqrt(rho[1]);

            if ((sq_norm == 0.0) || (rho[2] <= 0.0))
            {
                residual_scaling_ = sqrt_rho1_;
                alpha_sq_norm_ = 0.0;
            }
            else
            {
                const double D = 1.0 + 2.0 * sq_norm * rho[2] / rho[1];
                const double alpha = 1.0 - sqrt(D);
                residual_scaling_ = sqrt_rho1_ / (1 - alpha);
                alpha_sq_norm_ = alpha / sq_norm;
            }

            for (int i = 0; i < static_cast<int>(parameter_blocks.size()); i++)
            {
                jacobians[i] = sqrt_rho1_ * (jacobians[i] - alpha_sq_norm_ * residuals * (residuals.transpose() * jacobians[i]));
            }

            residuals *= residual_scaling_;
        }
    }

    MarginalizationInfo::~MarginalizationInfo()
    {
        for (auto it = parameter_block_data.begin(); it != parameter_block_data.end(); ++it)
        {
            delete[] it->second;
        }

        for (int i = 0; i < (int)factors.size(); i++)
        {
            delete[] factors[i]->raw_jacobians;
            delete factors[i]->cost_function;
            delete factors[i];
        }
    }

    void MarginalizationInfo::addResidualBlockInfo(ResidualBlockInfo *residual_block_info)
    {
        factors.emplace_back(residual_block_info);

        std::vector<double *> &parameter_blocks = residual_block_info->parameter_blocks;
        std::vector<int> parameter_block_sizes = residual_block_info->cost_function->parameter_block_sizes();

        for (int i = 0; i < static_cast<int>(residual_block_info->parameter_blocks.size()); i++)
        {
            double *addr = parameter_blocks[i];
            int size = parameter_block_sizes[i];
            parameter_block_size[reinterpret_cast<long>(addr)] = size;
        }

        for (int i = 0; i < static_cast<int>(residual_block_info->drop_set.size()); i++)
        {
            double *addr = parameter_blocks[residual_block_info->drop_set[i]];
            parameter_block_idx[reinterpret_cast<long>(addr)] = 0;
        }
    }

    void MarginalizationInfo::preMarginalize()
    {
        for (auto it : factors)
        {
            it->Evaluate();

            std::vector<int> block_sizes = it->cost_function->parameter_block_sizes();
            for (int i = 0; i < static_cast<int>(block_sizes.size()); i++)
            {
                long addr = reinterpret_cast<long>(it->parameter_blocks[i]);
                int size = block_sizes[i];
                if (parameter_block_data.find(addr) == parameter_block_data.end())
                {
                    double *data = new double[size];
                    memcpy(data, it->parameter_blocks[i], sizeof(double) * size);
                    parameter_block_data[addr] = data;
                }
            }
        }
    }

    int MarginalizationInfo::localSize(int size) const
    {
        return size == 4 ? 3 : size;
    }

    int MarginalizationInfo::globalSize(int size) const
    {
        return size == 3 ? 4 : size;
    }

    void* ThreadsConstructA(void* threadsstruct)
    {
        ThreadsStruct* p = ((ThreadsStruct*)threadsstruct);
        for (auto it : p->sub_factors)
        {
            for (int i = 0; i < static_cast<int>(it->parameter_blocks.size()); i++)
            {
                int idx_i = p->parameter_block_idx[reinterpret_cast<long>(it->parameter_blocks[i])];
                int size_i = p->parameter_block_size[reinterpret_cast<long>(it->parameter_blocks[i])];
                if (size_i == 4)
                {
                    size_i = 3;
                }
                Eigen::MatrixXd jacobian_i = it->jacobians[i].leftCols(size_i);
                for (int j = i; j < static_cast<int>(it->parameter_blocks.size()); j++)
                {
                    int idx_j = p->parameter_block_idx[reinterpret_cast<long>(it->parameter_blocks[j])];
                    int size_j = p->parameter_block_size[reinterpret_cast<long>(it->parameter_blocks[j])];
                    if (size_j == 4)
                    {
                        size_j = 3;
                    }
                    Eigen::MatrixXd jacobian_j = it->jacobians[j].leftCols(size_j);
                    if (i == j)
                    {
                        p->A.block(idx_i, idx_j, size_i, size_j) += jacobian_i.transpose() * jacobian_j;
                    }
                    else
                    {
                        p->A.block(idx_i, idx_j, size_i, size_j) += jacobian_i.transpose() * jacobian_j;
                        p->A.block(idx_j, idx_i, size_j, size_i) = p->A.block(idx_i, idx_j, size_i, size_j).transpose();
                    }
                }
                p->b.segment(idx_i, size_i) += jacobian_i.transpose() * it->residuals;
            }
        }
        return threadsstruct;
    }

    void MarginalizationInfo::marginalize()
    {
        int pos = 0;

#ifndef USE_AMM_INVERSE
        std::vector<std::pair<long, int>> block_idx_vec;
        block_idx_vec.reserve(parameter_block_idx.size());
        for(const auto& it : parameter_block_idx)
            block_idx_vec.emplace_back(it);

        std::sort(block_idx_vec.begin(), block_idx_vec.end(),
                  [&](const std::pair<long, int>& a, const std::pair<long, int>& b)
                  {
                      return parameter_block_size[a.first] < parameter_block_size[b.first];
                  });
        int point_count = 0;
        for(const auto& it : block_idx_vec)
        {
            const int local_size = localSize(parameter_block_size[it.first]);
            parameter_block_idx[it.first] = pos;
            pos += local_size;
            if(local_size == 1)
                point_count++;
        }
#else
        for (auto &it : parameter_block_idx)
        {
            it.second = pos;
            pos += localSize(parameter_block_size[it.first]);
        }
#endif

        m = pos;
        for (const auto &it : parameter_block_size)
        {
            if (parameter_block_idx.find(it.first) == parameter_block_idx.end())
            {
                parameter_block_idx[it.first] = pos;
                pos += localSize(it.second);
            }
        }

        n = pos - m;

        Eigen::MatrixXd A(pos, pos);
        Eigen::VectorXd b(pos);
        A.setZero();
        b.setZero();

        std::thread thread_process[NUM_THREADS];
        ThreadsStruct threadsstruct[NUM_THREADS];
        int i = 0;
        for (auto it : factors)
        {
            threadsstruct[i].sub_factors.push_back(it);
            i++;
            i = i % NUM_THREADS;
        }
        for (int i = 0; i < NUM_THREADS; i++)
        {
            threadsstruct[i].A = Eigen::MatrixXd::Zero(pos,pos);
            threadsstruct[i].b = Eigen::VectorXd::Zero(pos);
            threadsstruct[i].parameter_block_size = parameter_block_size;
            threadsstruct[i].parameter_block_idx = parameter_block_idx;
            thread_process[i] = std::thread(&ThreadsConstructA, (void*)&(threadsstruct[i]));
        }
        for(int i = NUM_THREADS - 1; i >= 0; i--)
        {
            if (thread_process[i].joinable()) {
                thread_process[i].join();
            }
            A += threadsstruct[i].A;
            b += threadsstruct[i].b;
        }

#ifndef USE_AMM_INVERSE

        Eigen::MatrixXd Amm = 0.5 * (A.block(0, 0, m, m) +
                                     A.block(0, 0, m, m).transpose());

        Eigen::VectorXd Amm_P(point_count);
        Eigen::VectorXd Amm_P_inv(point_count);
        for(int i = 0; i < point_count; ++i)
        {
            Amm_P[i] = Amm(i, i);
            Amm_P_inv[i] = 1.0 / (Amm_P[i]);
        }

        Eigen::MatrixXd Amm_Q = Amm.block(0, point_count, point_count, m - point_count);
        Eigen::MatrixXd Amm_R = Amm_Q.transpose();
        Eigen::MatrixXd Amm_S = Amm.block(point_count, point_count, m - point_count, m - point_count);
        Eigen::MatrixXd Amm_R_P_inv = Amm_R;
        for(int i = 0; i < Amm_R.rows(); ++i)
            for(int j = 0; j < Amm_R.cols(); ++j)
                Amm_R_P_inv(i, j) *= Amm_P_inv[j];

        Eigen::MatrixXd Amm_Schur = Amm_S - Amm_R_P_inv * Amm_Q; //Schur structure

        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> saes_Schur(Amm_Schur);
        Eigen::MatrixXd Amm_Schur_inv = saes_Schur.eigenvectors() * Eigen::VectorXd((saes_Schur.eigenvalues().array() > eps).select(
                saes_Schur.eigenvalues().array().inverse(), 0)).asDiagonal() * saes_Schur.eigenvectors().transpose();

        Eigen::MatrixXd Amm_inv = Amm;
        Amm_inv.setZero();
        Eigen::MatrixXd Q_Schur_inv_R = Amm_Q * Amm_Schur_inv * Amm_R;
        for (int i = 0; i < Q_Schur_inv_R.rows(); ++i)
        {
            for (int j = 0; j < Q_Schur_inv_R.cols(); ++j)
            {
                Q_Schur_inv_R(i, j) *= (Amm_P_inv[i] * Amm_P_inv[j]);
                if (i == j)
                    Q_Schur_inv_R(i, j) += Amm_P_inv[i];
            }
        }

        Amm_inv.block(0, 0, point_count, point_count) = Q_Schur_inv_R;

        Eigen::MatrixXd Q_Schur_inv = Amm_Q * Amm_Schur_inv;
        for(int i = 0; i < Q_Schur_inv.rows(); ++i)
            for(int j = 0; j < Q_Schur_inv.cols(); ++j)
                Q_Schur_inv(i, j) *= (-Amm_P_inv[i]);

        Amm_inv.block(0, point_count, point_count, m - point_count) = Q_Schur_inv;

        Eigen::MatrixXd Schur_inv_R = Amm_Schur_inv * Amm_R;
        for(int i = 0; i < Schur_inv_R.rows(); ++i)
            for(int j = 0; j < Schur_inv_R.cols(); ++j)
                Schur_inv_R(i, j) *= (-Amm_P_inv[j]);

        Amm_inv.block(point_count, 0, m - point_count, point_count) = Schur_inv_R;
        Amm_inv.block(point_count, point_count, m - point_count, m - point_count) = Amm_Schur_inv;

#else
        Eigen::MatrixXd Amm = 0.5 * (A.block(0, 0, m, m) + A.block(0, 0, m, m).transpose());
        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> saes(Amm);

        Eigen::MatrixXd Amm_inv = saes.eigenvectors() * Eigen::VectorXd((saes.eigenvalues().array() > eps).select(
            saes.eigenvalues().array().inverse(), 0)).asDiagonal() * saes.eigenvectors().transpose();
#endif

        if(false)
        {
            Eigen::MatrixXd identity = Amm_inv * Amm;
            for (int i = 0; i < identity.rows(); ++i)
            {
                for (int j = 0; j < identity.cols(); ++j)
                {
                    if(i == j)
                    {
                        if(std::abs(identity(i, j) - 1.0) > 1e-6)
                            LOG(WARNING)<<"Matrix inverse unexpected precision error.";
                    }
                    else
                    {
                        if(std::abs(identity(i, j)) > 1e-6)
                            LOG(WARNING)<<"Matrix inverse unexpected precision error.";
                    }
                }
            }
        }

        Eigen::VectorXd bmm = b.segment(0, m);
        Eigen::MatrixXd Amr = A.block(0, m, m, n);
        Eigen::MatrixXd Arm = A.block(m, 0, n, m);
        Eigen::MatrixXd Arr = A.block(m, m, n, n);
        Eigen::VectorXd brr = b.segment(m, n);
        Eigen::MatrixXd ArmAmm_inv = Arm * Amm_inv;
        A = Arr - ArmAmm_inv * Amr;
        b = brr - ArmAmm_inv * bmm;

        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> saes2(A);
        Eigen::VectorXd S = Eigen::VectorXd((saes2.eigenvalues().array() > eps).select(saes2.eigenvalues().array(), 0));
        Eigen::VectorXd S_inv = Eigen::VectorXd((saes2.eigenvalues().array() > eps).select(saes2.eigenvalues().array().inverse(), 0));

        Eigen::VectorXd S_sqrt = S.cwiseSqrt();
        Eigen::VectorXd S_inv_sqrt = S_inv.cwiseSqrt();

        linearized_jacobians = S_sqrt.asDiagonal() * saes2.eigenvectors().transpose();
        linearized_residuals = S_inv_sqrt.asDiagonal() * saes2.eigenvectors().transpose() * b;
    }

    std::vector<double *> MarginalizationInfo::getParameterBlocks(std::unordered_map<long, double *> &addr_shift)
    {
        std::vector<double *> keep_block_addr;
        keep_block_size.clear();
        keep_block_idx.clear();
        keep_block_data.clear();

        for (const auto &it : parameter_block_idx)
        {
            if (it.second >= m)
            {
                keep_block_size.push_back(parameter_block_size[it.first]);
                keep_block_idx.push_back(parameter_block_idx[it.first]);
                keep_block_data.push_back(parameter_block_data[it.first]);
                keep_block_addr.push_back(addr_shift[it.first]);
            }
        }
        sum_block_size = std::accumulate(std::begin(keep_block_size), std::end(keep_block_size), 0);

        return keep_block_addr;
    }

    MarginalizationFactor::MarginalizationFactor(MarginalizationInfo* _marginalization_info) : marginalization_info(_marginalization_info)
    {
        int cnt = 0;
        for (auto it : marginalization_info->keep_block_size)
        {
            mutable_parameter_block_sizes()->push_back(it);
            cnt += it;
        }
        set_num_residuals(marginalization_info->n);
    };

    bool MarginalizationFactor::Evaluate(double const *const *parameters, double *residuals, double **jacobians) const
    {
        int n = marginalization_info->n;
        int m = marginalization_info->m;
        Eigen::VectorXd dx(n);
        for (int i = 0; i < static_cast<int>(marginalization_info->keep_block_size.size()); i++)
        {
            int size = marginalization_info->keep_block_size[i];
            int idx = marginalization_info->keep_block_idx[i] - m;
            Eigen::VectorXd x = Eigen::Map<const Eigen::VectorXd>(parameters[i], size);
            Eigen::VectorXd x0 = Eigen::Map<const Eigen::VectorXd>(marginalization_info->keep_block_data[i], size);
            if (size != 4)
            {
                dx.segment(idx, size) = x - x0;
            }
            else
            {
                dx.segment<3>(idx, size - 1) = 2.0 * (Eigen::Quaterniond(x0(3), x0(0), x0(1), x0(2)).inverse() * Eigen::Quaterniond(x(3), x(0), x(1), x(2))).vec();
                if (!((Eigen::Quaterniond(x0(3), x0(0), x0(1), x0(2)).inverse() * Eigen::Quaterniond(x(3), x(0), x(1), x(2))).w() >= 0))
                {
                    dx.segment<3>(idx, size - 1) = 2.0 * - (Eigen::Quaterniond(x0(3), x0(0), x0(1), x0(2)).inverse() * Eigen::Quaterniond(x(3), x(0), x(1), x(2))).vec();
                }
            }
        }
        Eigen::Map<Eigen::VectorXd>(residuals, n) = marginalization_info->linearized_residuals + marginalization_info->linearized_jacobians * dx;
        if (jacobians)
        {
            for (int i = 0; i < static_cast<int>(marginalization_info->keep_block_size.size()); i++)
            {
                if (jacobians[i])
                {
                    int size = marginalization_info->keep_block_size[i], local_size = marginalization_info->localSize(size);
                    int idx = marginalization_info->keep_block_idx[i] - m;
                    Eigen::Map<Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>> jacobian(jacobians[i], n, size);
                    jacobian.setZero();
                    jacobian.leftCols(local_size) = marginalization_info->linearized_jacobians.middleCols(idx, local_size);
                }
            }
        }
        return true;
    }
} // namespace AR
