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



Eigen::Quaterniond Utility::toQuaterniond(const Eigen::Vector3d &v3d)
{
    double theta = v3d.norm();
    double half_theta = 0.5 * theta;

    double imag_factor;
    double real_factor = cos(half_theta);
    const double SMALL_EPS = 1e-10;
    if (theta < SMALL_EPS)
    {
        double theta_sq = theta * theta;
        double theta_po4 = theta_sq * theta_sq;
        imag_factor = 0.5 - 0.0208333 * theta_sq + 0.000260417 * theta_po4;
    }
    else
    {
        double sin_half_theta = sin(half_theta);
        imag_factor = sin_half_theta / theta;
    }

    return Eigen::Quaterniond(real_factor,
                              imag_factor * v3d.x(),
                              imag_factor * v3d.y(),
                              imag_factor * v3d.z());
}
