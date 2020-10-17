#include "include/holokit.h"

#include "distortion_renderer.h"
#include "head_tracker.h"
#include "calibrations/lens_distortion.h"
#include "params/screen_params.h"
#include "params/device_params.h"

// TODO(b/134142617): Revisit struct/class hierarchy.
struct HoloKitLensDistortion : holokit::LensDistortion {};
struct HoloKitDistortionRenderer : holokit::DistortionRenderer {};
struct HoloKitHeadTracker : holokit::HeadTracker {};

extern "C" {


HoloKitLensDistortion* HoloKitLensDistortion_create(
    const uint8_t* encoded_device_params, int size, int display_width,
    int display_height) {
    return 0;
    //reinterpret_cast<HoloKitLensDistortion*>(
//      new holokit::LensDistortion(encoded_device_params, size, display_width,
//                                    display_height));
}

void HoloKitLensDistortion_destroy(HoloKitLensDistortion* lens_distortion) {
  delete lens_distortion;
}

void HoloKitLensDistortion_getEyeFromHeadMatrix(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    float* eye_from_head_matrix) {
  static_cast<holokit::LensDistortion*>(lens_distortion)
      ->GetEyeFromHeadMatrix(eye, eye_from_head_matrix);
}

void HoloKitLensDistortion_getProjectionMatrix(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye, float z_near,
    float z_far, float* projection_matrix) {
  static_cast<holokit::LensDistortion*>(lens_distortion)
      ->GetEyeProjectionMatrix(eye, z_near, z_far, projection_matrix);
}

void HoloKitLensDistortion_getFieldOfView(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    float* field_of_view) {
  static_cast<holokit::LensDistortion*>(lens_distortion)
      ->GetEyeFieldOfView(eye, field_of_view);
}

void HoloKitLensDistortion_getDistortionMesh(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    HoloKitMesh* mesh) {
  *mesh = static_cast<holokit::LensDistortion*>(lens_distortion)
              ->GetDistortionMesh(eye);
}

HoloKitUv HoloKitLensDistortion_undistortedUvForDistortedUv(
    HoloKitLensDistortion* lens_distortion, const HoloKitUv* distorted_uv,
    HoloKitEye eye) {
  std::array<float, 2> in = {distorted_uv->u, distorted_uv->v};
  std::array<float, 2> out =
      static_cast<holokit::LensDistortion*>(lens_distortion)
          ->UndistortedUvForDistortedUv(in, eye);

  HoloKitUv ret;
  ret.u = out[0];
  ret.v = out[1];
  return ret;
}

HoloKitUv HoloKitLensDistortion_distortedUvForUndistortedUv(
    HoloKitLensDistortion* lens_distortion, const HoloKitUv* undistorted_uv,
    HoloKitEye eye) {
  std::array<float, 2> in = {undistorted_uv->u, undistorted_uv->v};
  std::array<float, 2> out =
      static_cast<holokit::LensDistortion*>(lens_distortion)
          ->DistortedUvForUndistortedUv(in, eye);

  HoloKitUv ret;
  ret.u = out[0];
  ret.v = out[1];
  return ret;
}

HoloKitDistortionRenderer* HoloKitDistortionRenderer_create() {
  return reinterpret_cast<HoloKitDistortionRenderer*>(
      new holokit::DistortionRenderer());
}

void HoloKitDistortionRenderer_destroy(
    HoloKitDistortionRenderer* renderer) {
  delete renderer;
}

void HoloKitDistortionRenderer_setMesh(HoloKitDistortionRenderer* renderer,
                                         const HoloKitMesh* mesh,
                                         HoloKitEye eye) {
  static_cast<holokit::DistortionRenderer*>(renderer)->SetMesh(mesh, eye);
}

void HoloKitDistortionRenderer_renderEyeToDisplay(
    HoloKitDistortionRenderer* renderer, int target_display, int x, int y,
    int width, int height, const HoloKitEyeTextureDescription* left_eye,
    const HoloKitEyeTextureDescription* right_eye) {
  static_cast<holokit::DistortionRenderer*>(renderer)->RenderEyeToDisplay(
      target_display, x, y, width, height, left_eye, right_eye);
}

HoloKitHeadTracker* HoloKitHeadTracker_create() {
  return reinterpret_cast<HoloKitHeadTracker*>(new holokit::HeadTracker());
}

void HoloKitHeadTracker_destroy(HoloKitHeadTracker* head_tracker) {
  delete head_tracker;
}

void HoloKitHeadTracker_pause(HoloKitHeadTracker* head_tracker) {
  static_cast<holokit::HeadTracker*>(head_tracker)->Pause();
}

void HoloKitHeadTracker_resume(HoloKitHeadTracker* head_tracker) {
  static_cast<holokit::HeadTracker*>(head_tracker)->Resume();
}

void HoloKitHeadTracker_getPose(HoloKitHeadTracker* head_tracker,
                                  int64_t timestamp_ns, float* position,
                                  float* orientation) {
  std::array<float, 3> out_position;
  std::array<float, 4> out_orientation;
  static_cast<holokit::HeadTracker*>(head_tracker)
      ->GetPose(timestamp_ns, out_position, out_orientation);
  std::memcpy(position, &out_position[0], 3 * sizeof(float));
  std::memcpy(orientation, &out_orientation[0], 4 * sizeof(float));
}


}  // extern "C"

