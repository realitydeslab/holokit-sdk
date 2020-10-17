#ifndef HOLOKIT_SDK_SCREEN_PARAMS_H_
#define HOLOKIT_SDK_SCREEN_PARAMS_H_

namespace holokit {
namespace screen_params {
static constexpr float kMetersPerInch = 0.0254f;

void getScreenSizeInMeters(int width_pixels, int height_pixels,
                           float* out_width_meters, float* out_height_meters);
}  // namespace screen_params
}  // namespace holokit

#endif  // HOLOKIT_SDK_SCREEN_PARAMS_H_
