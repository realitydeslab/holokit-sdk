#ifndef HOLOKIT_SDK_LENSDISTORTION_H_
#define HOLOKIT_SDK_LENSDISTORTION_H_

#include <array>
#include <memory>


#include "params/device_params.h"
#include "calibrations/distortion_mesh.h"
#include "calibrations/polynomial_radial_distortion.h"
#include "include/holokit.h"
#include "utils/matrix_4x4.h"

namespace holokit {

class LensDistortion {
 public:
  LensDistortion(const DeviceParams& device_params,
                                 int display_width, int display_height);

  virtual ~LensDistortion();
  // Tan angle units. "DistortedUvForUndistoredUv" goes through the forward
  // distort function. I.e. the lens. UndistortedUvForDistortedUv uses the
  // inverse distort function.
  std::array<float, 2> DistortedUvForUndistortedUv(
      const std::array<float, 2>& in, HoloKitEye eye) const;
  std::array<float, 2> UndistortedUvForDistortedUv(
      const std::array<float, 2>& in, HoloKitEye eye) const;
  void GetEyeFromHeadMatrix(HoloKitEye eye,
                            float* eye_from_head_matrix) const;
  void GetEyeProjectionMatrix(HoloKitEye eye, float z_near, float z_far,
                              float* projection_matrix) const;
  void GetEyeFieldOfView(HoloKitEye eye, float* field_of_view) const;
  HoloKitMesh GetDistortionMesh(HoloKitEye eye) const;
 private:
  struct ViewportParams;

  void UpdateParams();
  static float GetYEyeOffsetMeters(const DeviceParams& device_params,
                                   float screen_height_meters);
  static DistortionMesh* CreateDistortionMesh(
      HoloKitEye eye, const holokit::DeviceParams& device_params,
      const holokit::PolynomialRadialDistortion& distortion,
      const std::array<float, 4>& fov, float screen_width_meters,
      float screen_height_meters);
  static std::array<float, 4> CalculateFov(
      const holokit::DeviceParams& device_params,
      const holokit::PolynomialRadialDistortion& distortion,
      float screen_width_meters, float screen_height_meters);
  static void CalculateViewportParameters(HoloKitEye eye,
                                          const DeviceParams& device_params,
                                          const std::array<float, 4>& fov,
                                          float screen_width_meters,
                                          float screen_height_meters,
                                          ViewportParams* screen_params,
                                          ViewportParams* texture_params);
  static constexpr float DegreesToRadians(float angle);

  DeviceParams device_params_;

  float screen_width_meters_;
  float screen_height_meters_;
  std::array<std::array<float, 4>, 2> fov_;  // L, R, B, T
  std::array<Matrix4x4, 2> eye_from_head_matrix_;
  std::unique_ptr<DistortionMesh> left_mesh_;
  std::unique_ptr<DistortionMesh> right_mesh_;
  std::unique_ptr<PolynomialRadialDistortion> distortion_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_LENSDISTORTION_H_
