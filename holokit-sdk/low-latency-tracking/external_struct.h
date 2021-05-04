//
//  external_struct.h
//  holokit
//
//  Created by Yuan Wang on 2021/5/1.
//

#ifndef external_struct_h
#define external_struct_h

#include <vector>
#include <Eigen/Dense>

namespace AR {

    struct ImuAccData
    {
        double event_timestamp = 0.0;
        double delivery_timestamp = 0.0;
        double ax = 0.0;
        double ay = 0.0;
        double az = 0.0;
    };

    struct ImuGyrData
    {
        double event_timestamp = 0.0;
        double delivery_timestamp = 0.0;
        double wx = 0.0;
        double wy = 0.0;
        double wz = 0.0;
    };
    struct ImuMagData
    {
        double event_timestamp = 0.0;
        double delivery_timestamp = 0.0;
        double mx = 0.0;
        double my = 0.0;
        double mz = 0.0;
    };

    struct ARVector3d
    {
        double x = 0.0;
        double y = 0.0;
        double z = 0.0;
        ARVector3d(){}
        ARVector3d(const double tx,const double ty,const double tz):x(tx),y(ty),z(tz){}
    };
    struct ARQuaterniond
    {
        double w = 0.0;
        double x = 0.0;
        double y = 0.0;
        double z = 0.0;
        ARQuaterniond(){}

        ARQuaterniond(const double rw,const double rx,const double ry,const double rz):w(rw),x(rx),y(ry),z(rz){}
    };

    struct CAM_K
    {
        double fx = 0.0;
        double fy = 0.0;
        double px = 0.0;
        double py = 0.0;
        CAM_K(){}
        CAM_K(const double Fx,const double Fy,const double Px,const double Py):fx(Fx),fy(Fy),px(Px),py(Py){}

    };

    struct ARkitData
    {
        double event_timestamp = 0.0;
        double delivery_timestamp = 0.0;
        int frame_id = 0;
        CAM_K cam_k;
        ARVector3d ARkit_Position; //
        ARQuaterniond ARkit_Rotation;
        double sim_wait_time = 0.0;
    };


    struct ARResult {
        int frame_id = 0;
        double event_timestamp = 0.0;
        double delivery_timestamp = 0.0;

        ARVector3d P_wc;
        ARVector3d V_wc;
        ARQuaterniond Q_wc;

        ARVector3d bg; //bias
        ARVector3d ba;
    };

    struct ImuData
    {
        double inter_event_timestamp = 0.0; //acc event_time
        double inter_delivery_timestamp = 0.0; //max(acc_event_timestamp,gyr_event_timestamp)

        double acc_event_timestamp = 0.0;
        double acc_delivery_timestamp = 0.0;

        double gyr_event_timestamp = 0.0;
        double gyr_delivery_timestamp = 0.0;

        Eigen::Vector3d acc;
        Eigen::Vector3d gyr;
        ImuData(double acc_et,double acc_dt,double gyr_et,double gyr_dt)
        {
            acc_event_timestamp = acc_et;
            acc_delivery_timestamp = acc_dt;
            gyr_event_timestamp = gyr_et;
            gyr_delivery_timestamp = gyr_dt;
            inter_event_timestamp = acc_et;
            inter_delivery_timestamp = std::max(acc_dt,gyr_dt);
        }


    };

} // namespace AR

#endif /* external_struct_h */
