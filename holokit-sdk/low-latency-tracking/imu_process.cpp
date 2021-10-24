#include "imu_process.h"
#include "utility.h"
#include<math.h>

LowPassFilter::LowPassFilter(double _sample_freq, double _cutoff_freq):
sample_freq(_sample_freq),
cutoff_freq(_cutoff_freq)
{
    double fr = sample_freq/cutoff_freq;
    double ohm = tan(M_PI/fr);
    double c = 1.0f+2.0*cos(M_PI/4.0)*ohm + ohm*ohm;
    b0 = ohm*ohm/c;
    b1 = 2.0*b0;
    b2 = b0;
    a1 = 2.0*(ohm*ohm-1.0)/c;
    a2 = (1.0-2.0*cos(M_PI/4.0)*ohm+ohm*ohm)/c;
    delay_element_1 = {0,0,0};
    delay_element_2 = {0,0,0};
}


void LowPassFilter::lowpass_filter(const Vector3d &_sample, Vector3d& _out_put)
{

    if(cutoff_freq <= 0)
    {
        _out_put = _sample;
        return;
    }

    Vector3d delay_element_0 = _sample - delay_element_1 * a1 - delay_element_2 * a2;

    if (isinf(delay_element_0.norm())) {
        // don't allow bad values to propagate via the filter
        delay_element_0 = _sample;
    }

    _out_put = delay_element_0 * b0 + delay_element_1 * b1 + delay_element_2 * b2;

    delay_element_2 = delay_element_1;
    delay_element_1 = delay_element_0;
}

IMUFilter::IMUFilter():
acc_lwfilter(100,40),
gyro_lwfilter(100,40)
{

}


void IMUFilter::get_filted_imu(const Vector3d &_acc, const Vector3d &_gyro, Vector3d &_filted_acc, Vector3d &_filted_gyro)
{
    Vector3d lwf_acc(0,0,0);
    Vector3d lwf_gyro(0,0,0);
    acc_lwfilter.lowpass_filter(_acc, lwf_acc);
    gyro_lwfilter.lowpass_filter(_gyro, lwf_gyro);

    if(fabs(lwf_gyro.z()) <= 0.002)
    {
        lwf_gyro(2) = 0;
    }

    gauss_acc[gauss_filer_cnt] = lwf_acc;
    gauss_gyro[gauss_filer_cnt] = lwf_gyro;
    gauss_filer_cnt++;

    Vector3d filted_acc(0,0,0);
    Vector3d filted_gyro(0,0,0);
    for(int i=0; i<gauss_filer_cnt; i++)
    {
        double para = 1.0/gauss_filer_cnt;
        filted_acc += gauss_acc[i] * para;
        filted_gyro += gauss_gyro[i] * para;
    }

    if(gauss_filer_cnt >= 5)
    {
        gauss_filer_cnt = 0;
    }
    _filted_acc = filted_acc;
    _filted_gyro = filted_gyro;
}

void IMUFilter::get_filted_acc(const Vector3d &_acc, Vector3d &_filted_acc)
{
    Vector3d lwf_acc(0,0,0);
    acc_lwfilter.lowpass_filter(_acc, lwf_acc);

    gauss_acc.push_back(lwf_acc);

    Vector3d filted_acc(0,0,0);
    int acc_size = gauss_acc.size();
    for(int i=0; i<acc_size; i++)
    {
        double para = 1.0/acc_size;
        filted_acc += gauss_acc[i] * para;
    }

    if(acc_size >= 5)
    {
        gauss_acc.pop_front();
    }
    _filted_acc = filted_acc;
}


void IMUFilter::get_filted_gyro(const Vector3d &_gyro, Vector3d &_filted_gyro)
{
    Vector3d lwf_gyro(0,0,0);
//    gyro_lwfilter.lowpass_filter(_gyro, lwf_gyro);

////    if(fabs(lwf_gyro.z()) <= 0.002)
////    {
////        lwf_gyro(2) = 0;
////    }
    lwf_gyro = _gyro;
    gauss_gyro.push_back(lwf_gyro);

    Vector3d filted_gyro(0,0,0);
    int gyro_size = gauss_gyro.size();
    for(int i=0; i<gauss_gyro.size(); i++)
    {
        double para = 1.0/gyro_size;
        filted_gyro += gauss_gyro[i] * para;
    }

    if(gyro_size >= 2)
    {
        gauss_gyro.pop_front();
    }
    _filted_gyro = filted_gyro;
}




IMUProcessor::IMUProcessor()
{
    omega.setZero();
    omega_P.setZero();
    omega_I.setZero();

    ra_sum.setZero();
    omega_I_sum.setZero();

    dcm_matrix.setIdentity();
}

void IMUProcessor::reset_dcm()
{
    omega_I.setZero();
    omega_P.setZero();
    omega = {0,0,0};
    // if the caller wants us to try to recover to the current
    // attitude then calculate the dcm matrix from the current
    // roll/pitch/yaw values
    if (ypr.norm() == ypr.norm()) //yaw
    {
        dcm_matrix =Utility::ypr2R(ypr* 180/M_PI);//yaw
    }
    else
    {
        // Get body frame accel vector
        Vector3d initAccVec(0,0,0);
        initAccVec = acc;

        // the first vector may be invalid as the filter starts up
        if((initAccVec.norm() > 9.0 || initAccVec.norm() < 11.0))
        {
            Matrix3d r = Utility::g2R(initAccVec);
            Vector3d acc_ypr = Utility::R2ypr(r);
//            ypr(1) = atan2(initAccVec(0), sqrt(pow(initAccVec(1), initAccVec(2))));
//            // calculate initial roll angle
//            ypr(2) = atan2(-initAccVec(1), -initAccVec(2));
            ypr(1) = acc_ypr(1);
            ypr(2) = acc_ypr(2);
        }
        else
        {
            ypr(1) = 0.0;
            ypr(2) = 0.0;
        }
        dcm_matrix =Utility::ypr2R(Vector3d(0,ypr(1)* 180/M_PI ,ypr(2)*180/M_PI));
    }
}

int IMUProcessor::renorm(Vector3d const _a, Vector3d& _result)
{
    const double renorm_val = 1.0 / _a.norm();

    if (!(renorm_val < 2.0 && renorm_val > 0.5))
    {
        // this is larger than it should get - log it as a warning
        if (!(renorm_val < 1.0e6f && renorm_val > 1.0e-6f))
        {
            return 0;
        }
    }

    _result = _a * renorm_val;
    return 1;
}

void IMUProcessor::normalize()
{
    const double error = 0.5 * dcm_matrix.row(0).dot(dcm_matrix.row(1));
    const Vector3d t0 = dcm_matrix.row(0) - error * dcm_matrix.row(1);
    const Vector3d t1 = dcm_matrix.row(1) -  error * dcm_matrix.row(0);
    const Vector3d t2 = t0.cross(t1);

    Vector3d row0,row1,row2;
    if (!renorm(t0, row0) ||
        !renorm(t1, row1) ||
        !renorm(t2, row2))
    {
        // Our solution is blowing up and we will force back
        // to last euler angles
        dcm_matrix.row(0) = row0;
        dcm_matrix.row(1) = row1;
        dcm_matrix.row(2) = row2;
        reset_dcm();
    }
}

double IMUProcessor::P_gain(double _spin_rate)
{
    if (_spin_rate < ToRad(50))
    {
        return 1.0;
    }
    if (_spin_rate > ToRad(500))
    {
        return 10.0;
    }

    return _spin_rate/ToRad(50);
}


void IMUProcessor::check_matrix()
{
    if (dcm_matrix.norm() != dcm_matrix.norm())
    {
        printf("ERROR: DCM matrix NAN\n");
        reset_dcm();
        return;
    }
    // some DCM matrix values can lead to an out of range error in
    // the pitch calculation via asin().  These NaN values can
    // feed back into the rest of the DCM matrix via the
    // error_course value.
    if (!(dcm_matrix(2,0) < 1.0 && dcm_matrix(2,0) > -1.0))
    {
        // We have an invalid matrix. Force a normalisation.
        normalize();

        if (dcm_matrix != dcm_matrix ||
            fabsf(dcm_matrix(2,0)) > 1.0)
        {
            // normalisation didn't fix the problem! We're
            // in real trouble. All we can do is reset
            //Serial.printf("ERROR: DCM matrix error. _dcm_matrix.c.x=%f\n",
            //       _dcm_matrix.c.x);
            reset_dcm();
        }
    }
}


void IMUProcessor::drift_correction()
{
    Vector3d accel_body;
    Vector3d accel_ef;

    double error_rp = 1.0;

    accel_body = acc;
    accel_ef = dcm_matrix * accel_body;
    // integrate the accel vector in the earth frame between GPS readings
    ra_sum = ra_sum + accel_ef * delta_t;


    // keep a sum of the deltat values, so we know how much time
    // we have integrated over
    ra_dt += delta_t;

    // equation 9: get the corrected acceleration vector in earth frame. Units
    // are m/s/s
    Vector3d GA_e(0.0, 0.0, 1.0);

    if (ra_dt <= 0)
    {
        // waiting for more data
        return;
    }

    double ra_scale = 1.0/(ra_dt*9.8);

    Vector3d error;
    double error_dirn;
    Vector3d GA_b;
    double best_error = 0;
    ra_sum = ra_sum *  ra_scale;
    GA_b = ra_sum;
    if (GA_b.norm() == 0)
    {
        return;
    }

    GA_b = GA_b / GA_b.norm();
    if (GA_b != GA_b)
    {
        return;
    }

    error = GA_b.cross(GA_e);
    // Take dot product to catch case vectors are opposite sign and parallel
    error_dirn = GA_b.dot(GA_e);
    const double error_length = error.norm();
    best_error = error_length;
    // Catch case where orientation is 180 degrees out
    if (error_dirn < 0.0)
    {
        best_error = 1.0;
    }
    error(2) = 0.0;
    // convert the error term to body frame
    error = dcm_matrix.transpose() * error;

    if (error.norm()!=error.norm() || error!=error )
    {
        // don't allow bad values
        check_matrix();
        return;
    }

    error_rp = 0.8 * error_rp + 0.2 * best_error;

    // base the P gain on the spin rate
    const double spin_rate = omega.norm();
    double kp = 0.22; //0.2
    // sanity check _kp value
    if (kp < 0.05) {kp = 0.05;}
    kp = kp * P_gain(spin_rate);
    // we now want to calculate _omega_P and _omega_I. The
    // _omega_P value is what drags us quickly to the
    // accelerometer reading.
    omega_P = error * kp;

    double ki = 0.0187;   //0.0087
    // accumulate some integrator error
    if (spin_rate < ToRad(20))
    {
        omega_I_sum = omega_I_sum + error * ki * ra_dt;
        omega_I_sum_time += ra_dt;
    }

    if (omega_I_sum_time >= 5)
    {
        // limit the rate of change of omega_I to the hardware
        // reported maximum gyro drift rate. This ensures that
        // short term errors don't cause a buildup of omega_I
        // beyond the physical limits of the device
        const double change_limit = ToRad(0.5f/60) * omega_I_sum_time;
        omega_I_sum(0) = constrain(omega_I_sum(0), -change_limit, change_limit);
        omega_I_sum(1) = constrain(omega_I_sum(1), -change_limit, change_limit);
        omega_I_sum(2) = constrain(omega_I_sum(2), -change_limit, change_limit);
        omega_I = omega_I + omega_I_sum;
        omega_I_sum.setZero();
        omega_I_sum_time = 0;
    }

    omega_I(2) = 0.0;
    omega_P(2) = 0.0;
    // zero our accumulator ready for the next GPS step
    ra_sum.setZero();
    ra_dt = 0;
}

int IMUProcessor::mayhony_DCM(const Vector3d& _acc, const Vector3d& _gyro, const double _dt)
{
    imu_filter.get_filted_imu(_acc, _gyro, acc, gyro);

    omega = gyro;
    delta_t = _dt;

    if( delta_t > 2.0f)
    {
        reset_dcm();
        return 0;
        //if time is too long ,reset ,and the first time t_prev is 0 detlaT is big ,prevent it
    }

    if (delta_t > 0)
    {
        Vector3d temp_omega = omega + omega_I + omega_P;
        temp_omega.z() = gyro.z();
        temp_omega = temp_omega * delta_t;
        dcm_matrix = Utility::matrix_rotate(dcm_matrix, temp_omega);
    }

    normalize();
    drift_correction();
    check_matrix();

    ypr = Utility::R2ypr(dcm_matrix) * M_PI /180;

    return 1;
}


Vector3d IMUProcessor::get_ypr()
{
    return ypr*180/M_PI;
}
