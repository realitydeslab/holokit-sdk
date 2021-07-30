//
//  low_latency_tracking_api.h
//  holokit
//
//  Created by Yuchen on 2021/7/30.
//

#include <simd/simd.h>
#include "Eigen/Geometry"
#include "ceres/internal/eigen.h"

namespace holokit {

class LowLatencyTrackingApi {
    
public:
    LowLatencyTrackingApi() {};
    
    static std::unique_ptr<LowLatencyTrackingApi>& GetInstance();
    
    void GetPose(double target_timestamp, Eigen::Vector3d& position, Eigen::Quaterniond& rotation) const;
    
    void OnAccelerometerDataUpdated(double sensor_timestamp, const Eigen::Vector3d& acceleration);
    
    void OnGyroDataUpdated(double sensor_timestamp, const Eigen::Vector3d& rotationRate);
    
    void OnARKitDataUpdated(double sensor_timestamp, const Eigen::Vector3d& position, const Eigen::Quaterniond& rotation, const Eigen::Matrix<double, 3, 3> intrinsics);
    
private:
    static std::unique_ptr<LowLatencyTrackingApi> low_latency_tracking_api_;
    
}; // class LowLatencyTrackingApi

std::unique_ptr<LowLatencyTrackingApi> LowLatencyTrackingApi::low_latency_tracking_api_;

std::unique_ptr<LowLatencyTrackingApi>& LowLatencyTrackingApi::GetInstance() {
    return low_latency_tracking_api_;
}

} // namespace holokit
