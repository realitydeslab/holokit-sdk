#include "utility.h"

Eigen::Matrix3d Utility::g2R(const Eigen::Vector3d &g)
{
    Eigen::Matrix3d R0;
    Eigen::Vector3d ng1 = g.normalized();
    Eigen::Vector3d ng2(0, 0, 1.0);
    R0 = Eigen::Quaterniond::FromTwoVectors(ng1, ng2).toRotationMatrix();
    double yaw = Utility::R2ypr(R0).x();
    double pitch = Utility::R2ypr(R0).y();
    double roll = Utility::R2ypr(R0).z();
    printf("yaw is %f %f %f\n", yaw, pitch, roll);
    R0 = Utility::ypr2R(Eigen::Vector3d(-yaw, 0, 0)) * R0;
    printf("g= %f %f %f %f", g(0), g(1), g(2));
    return R0;
}
void Utility::Rt2T(const Eigen::Matrix3d &R, const Eigen::Vector3d &t, Eigen::Matrix4d &T)
{
    T << R(0, 0), R(0, 1), R(0, 2), t(0),
        R(1, 0), R(1, 1), R(1, 2), t(1),
        R(2, 0), R(2, 1), R(2, 2), t(2),
        0, 0, 0, 1;

}

void Utility::T2Rt(const Eigen::Matrix4d &T, Eigen::Matrix3d &R, Eigen::Vector3d &t)
{
    R << T(0, 0), T(0, 1), T(0, 2),
        T(1, 0), T(1, 1), T(1, 2),
        T(2, 0), T(2, 1), T(2, 2);
    t << T(0, 3), T(1, 3), T(2, 3);
}

void Utility::get_mean_and_stddev(const std::vector<double> &resultSet, double &mean, double &stddev)
{
    double sum = std::accumulate(std::begin(resultSet), std::end(resultSet), 0.0);
    mean = sum / resultSet.size(); //均值

    double accum = 0.0;
    std::for_each(std::begin(resultSet), std::end(resultSet), [&](const double d)
    {
        accum += (d - mean) * (d - mean);
    });

    stddev = sqrt(accum / (resultSet.size() - 1)); //方差
}

Matrix3d Utility::matrix_from_euler(Vector3d ypr)
{
    double cp = cosf(ypr(1));
    double sp = sinf(ypr(1));
    double sr = sinf(ypr(2));
    double cr = cosf(ypr(2));
    double sy = sinf(ypr(0));
    double cy = cosf(ypr(0));
    Eigen::Matrix3d m;
    m << cp * cy, (sr * sp * cy) - (cr * sy), (cr * sp * cy) + (sr * sy), cp * sy,
        (sr * sp * sy) + (cr * cy), (cr * sp * sy) - (sr * cy), -sp,
        sr * cp, cr * cp;
    return m;
}


Matrix3d Utility:: matrix_rotate(Matrix3d m,Vector3d g)
{
    Matrix3d temp_matrix;
    temp_matrix << 1, -g.z(), g.y(),
                   g.z(), 1, -g.x(),
                   -g.y(), g.x(), 1;

    m = m * temp_matrix;
    return m;
}


double Utility::safe_asin(double v)
{

    if (isnan(v))
    {
        return 0.0f;
    }
    if (v >= 1.0f)
    {
        return PI / 2;
    }
    if (v <= -1.0f)
    {
        return -PI / 2;
    }
    return asinf(v);
}

double Utility::safe_acos(double v)
{

    if (isnan(v))
    {
        return 0.0f;
    }
    if (v >= 1.0f)
    {
        return 0;
    }
    if (v <= -1.0f)
    {
        return 0;
    }
    return acosf(v);
}

Quaterniond Utility::averageQuaternion(Quaterniond &sum, const Quaterniond &new_q, const Quaterniond &first_q, int num)
{

    double w = 0.0;
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    Quaterniond tmp_q;
    double dot = new_q.dot(first_q);
//    std::cout << "dot" << dot << std::endl;
    if(dot < 0)
    {
        tmp_q.w() = -new_q.w();
        tmp_q.x() = -new_q.x();
        tmp_q.y() = -new_q.y();
        tmp_q.z() = -new_q.z();

    }else
    {
        tmp_q.w() = new_q.w();
        tmp_q.x() = new_q.x();
        tmp_q.y() = new_q.y();
        tmp_q.z() = new_q.z();
    }
//    std::cout << "tmp_q" << tmp_q.coeffs().transpose() << std::endl;
    //Average the values
    double addDet = 1/(double)num;
//    std::cout << "addDet " << addDet << std::endl;
//    std::cout << "sum " << sum.coeffs().transpose() << std::endl;
    sum.w() += tmp_q.w();
    w = sum.w() * addDet;
    sum.x() += tmp_q.x();
    x = sum.x() * addDet;
    sum.y() += tmp_q.y();
    y = sum.y() * addDet;
    sum.z() += tmp_q.z();
    z = sum.z() * addDet;
//    std::cout << "sum z" << sum.z() << std::endl;
//    std::cout << "z" << z << std::endl;
    Quaterniond average_q(w,x,y,z);
//    std::cout << "average_q" << average_q.coeffs().transpose() << std::endl;
    average_q.normalize();

    //note: if speed is an issue, you can skip the normalization step
    return average_q;
}

Quaterniond Utility::averageQuaternionNew(Quaterniond &aver_q, const Quaterniond &new_q, const Quaterniond &first_q, int num)
{

    double w = 0.0;
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    Quaterniond tmp_q;
    double dot = new_q.dot(first_q);
    //std::cout << "dot" << dot << std::endl;
    if(dot < 0)
    {
        tmp_q.w() = -new_q.w();
        tmp_q.x() = -new_q.x();
        tmp_q.y() = -new_q.y();
        tmp_q.z() = -new_q.z();

    }else
    {
        tmp_q.w() = new_q.w();
        tmp_q.x() = new_q.x();
        tmp_q.y() = new_q.y();
        tmp_q.z() = new_q.z();
    }

    //Average the values
    double addDet = 1/(double)num;
    w = (2*tmp_q.w() + (num-1)*aver_q.w())/(num+1);
    x = (2*tmp_q.x() + (num-1)*aver_q.x())/(num+1);
    y = (2*tmp_q.y() + (num-1)*aver_q.y())/(num+1);
    z = (2*tmp_q.z() + (num-1)*aver_q.z())/(num+1);

    Quaterniond average_q(w,x,y,z);
//    std::cout << "average_q" << average_q.coeffs().transpose() << std::endl;
    average_q.normalize();

    //note: if speed is an issue, you can skip the normalization step
    return average_q;
}

Quaterniond Utility::ConvertToEigenQuaterniond(Eigen::Vector3d euler)
{
    return Eigen::AngleAxisd(euler[0], ::Eigen::Vector3d::UnitX()) *
    Eigen::AngleAxisd(euler[1], ::Eigen::Vector3d::UnitY()) *
    Eigen::AngleAxisd(euler[2], ::Eigen::Vector3d::UnitZ());
}
