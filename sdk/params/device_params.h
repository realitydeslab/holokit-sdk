#ifndef HOLOKIT_SDK_DEVICE_PARAMS_H_
#define HOLOKIT_SDK_DEVICE_PARAMS_H_

#include <string>
#include <vector>

namespace holokit {
class DeviceParams {
public:
    DeviceParams();
    virtual ~DeviceParams();
    
    std::string model;
    double screen_to_lens_distance;
    double inter_lens_distance;
    double tray_to_lens_distance;
    std::vector<float> distortion_coefficients;
    std::vector<float> left_eye_field_of_view_angles;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_DEVICE_PARAMS_H_

