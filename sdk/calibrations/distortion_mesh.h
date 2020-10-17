#ifndef HOLOKIT_SDK_DISTORTION_MESH_H_
#define HOLOKIT_SDK_DISTORTION_MESH_H_

#include <vector>

#include "include/holokit.h"
#include "calibrations/polynomial_radial_distortion.h"

namespace holokit {

class DistortionMesh {
 public:
  DistortionMesh(const PolynomialRadialDistortion& distortion,
                 // Units of the following parameters are tan-angle units.
                 float screen_width, float screen_height,
                 float x_eye_offset_screen, float y_eye_offset_screen,
                 float texture_width, float texture_height,
                 float x_eye_offset_texture, float y_eye_offset_texture);
  virtual ~DistortionMesh() = default;
  HoloKitMesh GetMesh() const;

 private:
  static constexpr int kResolution = 40;
  std::vector<int> index_data_;
  std::vector<float> vertex_data_;
  std::vector<float> uvs_data_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_DISTORTION_MESH_H_
