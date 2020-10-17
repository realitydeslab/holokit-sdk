#ifndef HOLOKIT_SDK_INCLUDE_HOLOKIT_H_
#define HOLOKIT_SDK_INCLUDE_HOLOKIT_H_

#include <stdint.h>

/// @defgroup types HoloKit SDK types
/// @brief Various types used in the HoloKit SDK.
/// @{

/// Struct to hold UV coordinates.
typedef struct HoloKitUv {
  /// u coordinate.
  float u;
  /// v coordinate.
  float v;
} HoloKitUv;

/// Enum to distinguish left and right eyes.
typedef enum HoloKitEye {
  /// Left eye.
  kLeft = 0,
  /// Right eye.
  kRight = 1,
} HoloKitEye;

/// Struct representing a 3D mesh with 3D vertices and corresponding UV
/// coordinates.
typedef struct HoloKitMesh {
  /// Indices buffer.
  int* indices;
  /// Number of indices.
  int n_indices;
  /// Vertices buffer. 2 floats per vertex: x, y.
  float* vertices;
  /// UV coordinates buffer. 2 floats per uv: u, v.
  float* uvs;
  /// Number of vertices.
  int n_vertices;
} HoloKitMesh;

/// Struct to hold information about an eye texture.
typedef struct HoloKitEyeTextureDescription {
  /// The texture with eye pixels.
  uint32_t texture;
  /// u coordinate of the left side of the eye.
  float left_u;
  /// u coordinate of the right side of the eye.
  float right_u;
  /// v coordinate of the top side of the eye.
  float top_v;
  /// v coordinate of the bottom side of the eye.
  float bottom_v;
} HoloKitEyeTextureDescription;

/// An opaque Lens Distortion object.
typedef struct HoloKitLensDistortion HoloKitLensDistortion;

/// An opaque Distortion Renderer object.
typedef struct HoloKitDistortionRenderer HoloKitDistortionRenderer;

/// An opaque Head Tracker object.
typedef struct HoloKitHeadTracker HoloKitHeadTracker;

/// @}


#ifdef __cplusplus
extern "C" {
#endif


/////////////////////////////////////////////////////////////////////////////
// Lens Distortion
/////////////////////////////////////////////////////////////////////////////
/// @defgroup lens-distortion Lens Distortion
/// @brief This module calculates the projection and eyes distortion matrices,
///     based on the device (HoloKit viewer) and screen parameters. It also
///     includes functions to calculate the distortion for a single point.
/// @{

/// Creates a new lens distortion object and initializes it with the values from
/// @c encoded_device_params.
///
/// @param[in]      encoded_device_params   The device parameters serialized
///     using holokit_device.proto.
/// @param[in]      size                    Size in bytes of
///     encoded_device_params.
/// @param[in]      display_width           Size in pixels of display width.
/// @param[in]      display_height          Size in pixels of display height.
/// @return         Lens distortion object pointer.
HoloKitLensDistortion* HoloKitLensDistortion_create(
    const uint8_t* encoded_device_params, int size, int display_width,
    int display_height);

/// Destroys and releases memory used by the provided lens distortion object.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
void HoloKitLensDistortion_destroy(HoloKitLensDistortion* lens_distortion);

/// Gets the eye_from_head matrix for a particular eye.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      eye                     Desired eye.
/// @param[out]     eye_from_head_matrix    4x4 float eye from head matrix.
void HoloKitLensDistortion_getEyeFromHeadMatrix(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    float* eye_from_head_matrix);

/// Gets the ideal projection matrix for a particular eye.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      eye                     Desired eye.
/// @param[in]      z_near                  Near clip plane z-axis coordinate.
/// @param[in]      z_far                   Far clip plane z-axis coordinate.
/// @param[out]     projection_matrix       4x4 float ideal projection matrix.
void HoloKitLensDistortion_getProjectionMatrix(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye, float z_near,
    float z_far, float* projection_matrix);

/// Gets the field of view half angles for a particular eye.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      eye                     Desired eye.
/// @param[out]     field_of_view           4x1 float half angles in radians,
///                                         angles are disposed [left, right,
///                                         bottom, top].
void HoloKitLensDistortion_getFieldOfView(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    float* field_of_view);

/// Gets the distortion mesh for a particular eye.
///
/// Important: The distorsion mesh that is returned by this function becomes
/// invalid if HoloKitLensDistortion is destroyed.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      eye                     Desired eye.
/// @param[out]     mesh                    Distortion mesh.
void HoloKitLensDistortion_getDistortionMesh(
    HoloKitLensDistortion* lens_distortion, HoloKitEye eye,
    HoloKitMesh* mesh);

/// Applies lens inverse distortion function to a point normalized [0,1] in
/// pre-distortion (eye texture) space.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      distorted_uv            Distorted UV point.
/// @param[in]      eye                     Desired eye.
/// @return         Point normalized [0,1] in the screen post distort space.
HoloKitUv HoloKitLensDistortion_undistortedUvForDistortedUv(
    HoloKitLensDistortion* lens_distortion, const HoloKitUv* distorted_uv,
    HoloKitEye eye);

/// Applies lens distortion function to a point normalized [0,1] in the screen
/// post-distortion space.
///
/// @param[in]      lens_distortion         Lens distortion object pointer.
/// @param[in]      undistorted_uv          Undistorted UV point.
/// @param[in]      eye                     Desired eye.
/// @return         Point normalized [0,1] in pre distort space (eye texture
///     space).
HoloKitUv HoloKitLensDistortion_distortedUvForUndistortedUv(
    HoloKitLensDistortion* lens_distortion, const HoloKitUv* undistorted_uv,
    HoloKitEye eye);
/// @}

/////////////////////////////////////////////////////////////////////////////
// Distortion Renderer
/////////////////////////////////////////////////////////////////////////////
/// @defgroup distortion-renderer Distortion Renderer
/// @brief This module renders the eyes textures into the display.
///
/// Important: This module functions must be called from the render thread.
/// @{

/// Creates a new distortion renderer object. Must be called from render thread.
///
/// @return         Distortion renderer object pointer
HoloKitDistortionRenderer* HoloKitDistortionRenderer_create();

/// Destroys and releases memory used by the provided distortion renderer
/// object. Must be called from render thread.
///
/// @param[in]      renderer                Distortion renderer object pointer.
void HoloKitDistortionRenderer_destroy(HoloKitDistortionRenderer* renderer);

/// Sets Distortion Mesh for a particular eye. Must be called from render
/// thread.
///
/// @param[in]      renderer                Distortion renderer object pointer.
/// @param[in]      mesh                    Distortion mesh.
/// @param[in]      eye                     Desired eye.
void HoloKitDistortionRenderer_setMesh(HoloKitDistortionRenderer* renderer,
                                         const HoloKitMesh* mesh,
                                         HoloKitEye eye);

/// Renders eye textures to a rectangle in the display. Must be called from
/// render thread.
///
/// @param[in]      renderer                Distortion renderer object pointer.
/// @param[in]      target_display          Target display.
/// @param[in]      x                       x coordinate of the rectangle's
///                                         lower left corner in pixels.
/// @param[in]      y                       y coordinate of the rectangle's
///                                         lower left corner in pixels.
/// @param[in]      width                   Size in pixels of the rectangle's
///                                         width.
/// @param[in]      height                  Size in pixels of the rectangle's
///                                         height.
/// @param[in]      left_eye                Left eye texture description.
/// @param[in]      right_eye               Right eye texture description.
void HoloKitDistortionRenderer_renderEyeToDisplay(
    HoloKitDistortionRenderer* renderer, int target_display, int x, int y,
    int width, int height, const HoloKitEyeTextureDescription* left_eye,
    const HoloKitEyeTextureDescription* right_eye);

/// @}

/////////////////////////////////////////////////////////////////////////////
// Head Tracker
/////////////////////////////////////////////////////////////////////////////
/// @defgroup head-tracker Head Tracker
/// @brief This module calculates the predicted head's pose for a given
///     timestamp. It takes data from accelerometer and gyroscope sensors and
///     uses a Kalman filter to generate the output value. The head's pose is
///     returned as a quaternion. To have control of the usage of the sensors,
///     this module also includes pause and resume functions.
/// @{

/// Creates a new head tracker object.
///
/// @return         head tracker object pointer
HoloKitHeadTracker* HoloKitHeadTracker_create();

/// Destroys and releases memory used by the provided head tracker object.
///
/// @param[in]      head_tracker            Head tracker object pointer.
void HoloKitHeadTracker_destroy(HoloKitHeadTracker* head_tracker);

/// Pauses head tracker and underlying device sensors.
///
/// @param[in]      head_tracker            Head tracker object pointer.
void HoloKitHeadTracker_pause(HoloKitHeadTracker* head_tracker);

/// Resumes head tracker and underlying device sensors.
///
/// @param[in]      head_tracker            Head tracker object pointer.
void HoloKitHeadTracker_resume(HoloKitHeadTracker* head_tracker);

/// Gets the predicted head pose for a given timestamp.
///
/// @param[in]      head_tracker            Head tracker object pointer.
/// @param[in]      timestamp_ns            The timestamp for the pose in
///     nanoseconds in system monotonic clock.
/// @param[out]     position                3 floats for (x, y, z).
/// @param[out]     orientation             4 floats for quaternion
void HoloKitHeadTracker_getPose(HoloKitHeadTracker* head_tracker,
                                  int64_t timestamp_ns, float* position,
                                  float* orientation);

/// @}

#ifdef __cplusplus
}
#endif

#endif  // HOLOKIT_SDK_INCLUDE_HOLOKIT_H_
