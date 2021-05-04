//
//  initial_alignment.hpp
//  holokit-sdk
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef initial_alignment_h
#define initial_alignment_h

#include <map>
#include <vector>
#include <Eigen/Dense>
#include "integration_base.h"
namespace AR {



    class AlignmentFrame
    {
    public:
        AlignmentFrame(){};
        AlignmentFrame(const ARkitData & cur_arkit_data)
        {
            ARkit_data = cur_arkit_data;
        };
        ARkitData ARkit_data;
        //Each initialization requires recalculation of R, T
        Eigen::Matrix3d R; //Rco_bk
        Eigen::Vector3d T; //tco_bk
        IntegrationBase *pre_integration;
    };

    class Alignment
    {
    public:
        Alignment(){};
        bool VisualIMUAlignment(std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d* Bgs, Eigen::Vector3d &g, Eigen::VectorXd &x);
    private:
        void solveGyroscopeBias(const std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d *Bgs);
        Eigen::MatrixXd TangentBasis(const Eigen::Vector3d &g0);
        void RefineGravity(std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d &g,
                Eigen::VectorXd &x);
        bool LinearAlignment(std::map<double, AlignmentFrame> &all_image_frame, Eigen::Vector3d &g, Eigen::VectorXd &x);
    };
} // namespace AR


#endif /* initial_alignment_hpp */
