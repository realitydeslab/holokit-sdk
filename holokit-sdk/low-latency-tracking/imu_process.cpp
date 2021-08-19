#include "imu_process.h"
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
acc_lwfilter(100,30),
gyro_lwfilter(100,20)
{

}


void IMUFilter::get_filted_gyro(const Vector3d &_gyro, Vector3d &_filted_gyro)
{
    Vector3d lwf_gyro(0,0,0);
    gyro_lwfilter.lowpass_filter(_gyro, lwf_gyro);

//    if(fabs(lwf_gyro.z()) <= 0.002)
//    {
//        lwf_gyro(2) = 0;
//    }

    gauss_gyro[gauss_filer_cnt] = lwf_gyro;
    gauss_filer_cnt++;

    Vector3d filted_gyro(0,0,0);
    for(int i=0; i<gauss_filer_cnt; i++)
    {
        double para = 1.0/gauss_filer_cnt;
        filted_gyro += gauss_gyro[i] * para;
    }

    if(gauss_filer_cnt >= 5)
    {
        gauss_filer_cnt = 0;
    }

    _filted_gyro = filted_gyro;
}


void IMUFilter::get_filted_acc(const Vector3d &_acc, Vector3d &_filted_acc)
{
    Vector3d lwf_acc(0,0,0);
    acc_lwfilter.lowpass_filter(_acc, lwf_acc);

    gauss_acc[gauss_filer_cnt] = lwf_acc;
    gauss_filer_cnt++;


    Vector3d filted_acc(0,0,0);
    for(int i=0; i<gauss_filer_cnt; i++)
    {
        double para = 1.0/gauss_filer_cnt;
        filted_acc += gauss_acc[i] * para;
    }
    _filted_acc = filted_acc;

    if(gauss_filer_cnt >= 5)
    {
        gauss_filer_cnt = 0;
    }

}
