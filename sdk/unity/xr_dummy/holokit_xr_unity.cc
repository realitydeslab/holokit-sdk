/*
 * Copyright 2020 Google LLC. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "unity/xr_unity_plugin/holokit_xr_unity.h"

#include <stdint.h>
#include <time.h>
#include <unistd.h>

#include <array>
#include <atomic>
#include <cstring>
#include <memory>
#include <mutex>
#include <vector>


#include "include/holokit.h"

// The following block makes log macros available for Android and iOS.
//#if __APPLE__
//#include <CoreFoundation/CFString.h>
//#include <CoreFoundation/CoreFoundation.h>
//extern "C" {
//void NSLog(CFStringRef format, ...);
//}
//#define LOGW(fmt, ...) \
//  NSLog(CFSTR("[%s : %d] " fmt), __FILE__, __LINE__, ##__VA_ARGS__)
//#define LOGD(fmt, ...) \
//  NSLog(CFSTR("[%s : %d] " fmt), __FILE__, __LINE__, ##__VA_ARGS__)
//#define LOGE(fmt, ...) \
//  NSLog(CFSTR("[%s : %d] " fmt), __FILE__, __LINE__, ##__VA_ARGS__)
//#define LOGF(fmt, ...) \
//  NSLog(CFSTR("[%s : %d] " fmt), __FILE__, __LINE__, ##__VA_ARGS__)
//#elif
//#define LOGW(...)
//#define LOGD(...)
//#define LOGE(...)
//#define LOGF(...)
//#endif

#define LOGW(...)
#define LOGD(...)
#define LOGE(...)
#define LOGF(...)

// @def Forwards the call to CheckGlError().
#define CHECKGLERROR(label) CheckGlError(__FILE__, __LINE__)

namespace {

/**
 * Checks for OpenGL errors, and crashes if one has occurred.  Note that this
 * can be an expensive call, so real applications should call this rarely.
 *
 * @param file File name
 * @param line Line number
 * @param label Error label
 */
//void CheckGlError(const char* file, int line) {
//  int gl_error = glGetError();
//  if (gl_error != GL_NO_ERROR) {
//    LOGF("[%s : %d] GL error: %d", file, line, gl_error);
//    // Crash immediately to make OpenGL errors obvious.
//    abort();
//  }
//}

// TODO(b/155457703): De-dupe GL utility function here and in
// distortion_renderer.cc
//GLuint LoadShader(GLenum shader_type, const char* source) {
//  GLuint shader = glCreateShader(shader_type);
//  glShaderSource(shader, 1, &source, nullptr);
//  glCompileShader(shader);
//  CHECKGLERROR("glCompileShader");
//  GLint result = GL_FALSE;
//  glGetShaderiv(shader, GL_COMPILE_STATUS, &result);
//  if (result == GL_FALSE) {
//    int log_length;
//    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_length);
//    if (log_length == 0) {
//      return 0;
//    }
//
//    std::vector<char> log_string(log_length);
//    glGetShaderInfoLog(shader, log_length, nullptr, log_string.data());
//    LOGE("Could not compile shader of type %d: %s", shader_type,
//                   log_string.data());
//
//    shader = 0;
//  }
//
//  return shader;
//}

// TODO(b/155457703): De-dupe GL utility function here and in
// distortion_renderer.cc
//GLuint CreateProgram(const char* vertex, const char* fragment) {
//  GLuint vertex_shader = LoadShader(GL_VERTEX_SHADER, vertex);
//  if (vertex_shader == 0) {
//    return 0;
//  }
//
//  GLuint fragment_shader = LoadShader(GL_FRAGMENT_SHADER, fragment);
//  if (fragment_shader == 0) {
//    return 0;
//  }
//
//  GLuint program = glCreateProgram();
//
//  glAttachShader(program, vertex_shader);
//  glAttachShader(program, fragment_shader);
//  glLinkProgram(program);
//  CHECKGLERROR("glLinkProgram");
//
//  GLint result = GL_FALSE;
//  glGetProgramiv(program, GL_LINK_STATUS, &result);
//  if (result == GL_FALSE) {
//    int log_length;
//    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &log_length);
//    if (log_length == 0) {
//      return 0;
//    }
//
//    std::vector<char> log_string(log_length);
//    glGetShaderInfoLog(program, log_length, nullptr, log_string.data());
//    LOGE("Could not compile program: %s", log_string.data());
//
//    return 0;
//  }
//
//  glDetachShader(program, vertex_shader);
//  glDetachShader(program, fragment_shader);
//  glDeleteShader(vertex_shader);
//  glDeleteShader(fragment_shader);
//  CHECKGLERROR("GlCreateProgram");
//
//  return program;
//}

/// @brief Vertex shader for RenderWidget.
const char kWidgetVertexShader[] =
  R"glsl(
  attribute vec2 aPosition;
  attribute vec2 aTexCoords;
  varying vec2 vTexCoords;
  void main() {
    gl_Position = vec4(aPosition, 0, 1);
    vTexCoords = aTexCoords;
  }
  )glsl";

/// @brief Fragment shader for RenderWidget.
const char kWidgetFragmentShader[] =
  R"glsl(
  precision mediump float;
  varying vec2 vTexCoords;
  uniform sampler2D uTexture;
  void main() {
    gl_FragColor = texture2D(uTexture, vTexCoords);
  }
  )glsl";

}  // namespace

// TODO(b/151087873) Convert into single line namespace declaration.
namespace holokit {
namespace unity {

// @brief It provides the implementation of the PImpl pattern for the HoloKit
//        SDK C-API.
class HoloKitApi::HoloKitApiImpl {
 public:
  // @brief Default contructor. See attributes for default initialization.
  HoloKitApiImpl() = default;

  // @brief Destructor.
  // @details Frees GL resources, HeadTracker module and Distortion Renderer
  //          module.
  ~HoloKitApiImpl() { GlTeardown(); }

  void InitHeadTracker() {
    if (head_tracker_ == nullptr) {
//      head_tracker_.reset(HoloKitHeadTracker_create());
    }
//    HoloKitHeadTracker_resume(head_tracker_.get());
  }

  void PauseHeadTracker() {
    if (head_tracker_ == nullptr) {
      LOGW("Uninitialized head tracker was paused.");
      return;
    }
//    HoloKitHeadTracker_pause(head_tracker_.get());
  }

  void ResumeHeadTracker() {
    if (head_tracker_ == nullptr) {
      LOGW("Uninitialized head tracker was resumed.");
      return;
    }
//    HoloKitHeadTracker_resume(head_tracker_.get());
  }

  void GetHeadTrackerPose(float* position, float* orientation) {
    if (head_tracker_ == nullptr) {
      LOGW("Uninitialized head tracker was queried for the pose.");
      position[0] = 0.0f;
      position[1] = 0.0f;
      position[2] = 0.0f;
      orientation[0] = 0.0f;
      orientation[1] = 0.0f;
      orientation[2] = 0.0f;
      orientation[3] = 1.0f;
      return;
    }
//    HoloKitHeadTracker_getPose(head_tracker_.get(),
//                                 HoloKitApiImpl::GetMonotonicTimeNano() +
//                                     kPredictionTimeWithoutVsyncNanos,
//                                 position, orientation);
  }

  static void ScanDeviceParams() {
//    HoloKitQrCode_scanQrCodeAndSaveDeviceParams();
  }

  void UpdateDeviceParams() {
    // Updates the screen size.
    screen_params_ = unity_screen_params_;

    // Get saved device parameters
    uint8_t* data;
    int size;
//    HoloKitQrCode_getSavedDeviceParams(&data, &size);
    HoloKitLensDistortion* lens_distortion;
//    if (size == 0) {
      // Loads HoloKit V1 device parameters when no device parameters are
      // available.
//      HoloKitQrCode_getHoloKitV1DeviceParams(&data, &size);
//      lens_distortion = HoloKitLensDistortion_create(
//          data, size, screen_params_.width, screen_params_.height);
//    } else {
//      lens_distortion = HoloKitLensDistortion_create(
//          data, size, screen_params_.width, screen_params_.height);
//      HoloKitQrCode_destroy(data);
//    }
//    lens_distortion = HoloKitLensDistortion_create(
//              data, size, screen_params_.width, screen_params_.height);
//    device_params_changed_ = false;

//    GlSetup();

//    distortion_renderer_.reset(HoloKitDistortionRenderer_create());

//    HoloKitLensDistortion_getDistortionMesh(
//        lens_distortion, HoloKitEye::kLeft,
//        &eye_data_[HoloKitEye::kLeft].distortion_mesh);
//    HoloKitLensDistortion_getDistortionMesh(
//        lens_distortion, HoloKitEye::kRight,
//        &eye_data_[HoloKitEye::kRight].distortion_mesh);
//
//    HoloKitDistortionRenderer_setMesh(
//        distortion_renderer_.get(),
//        &eye_data_[HoloKitEye::kLeft].distortion_mesh, HoloKitEye::kLeft);
//    HoloKitDistortionRenderer_setMesh(
//        distortion_renderer_.get(),
//        &eye_data_[HoloKitEye::kRight].distortion_mesh, HoloKitEye::kRight);

    // Get eye matrices
//    HoloKitLensDistortion_getEyeFromHeadMatrix(
//        lens_distortion, HoloKitEye::kLeft,
//        eye_data_[HoloKitEye::kLeft].eye_from_head_matrix);
//    HoloKitLensDistortion_getEyeFromHeadMatrix(
//        lens_distortion, HoloKitEye::kRight,
//        eye_data_[HoloKitEye::kRight].eye_from_head_matrix);
//    HoloKitLensDistortion_getFieldOfView(lens_distortion, HoloKitEye::kLeft,
//                                           eye_data_[HoloKitEye::kLeft].fov);
//    HoloKitLensDistortion_getFieldOfView(lens_distortion,
//                                           HoloKitEye::kRight,
//                                           eye_data_[HoloKitEye::kRight].fov);
//
//    HoloKitLensDistortion_destroy(lens_distortion);

//    CHECKGLERROR("UpdateDeviceParams");
  }

  void GetEyeMatrices(int eye, float* eye_from_head, float* fov) {
    std::memcpy(eye_from_head, eye_data_[eye].eye_from_head_matrix,
                sizeof(float) * 16);
    std::memcpy(fov, eye_data_[eye].fov, sizeof(float) * 4);
  }

  void RenderEyesToDisplay(int gl_framebuffer_id) {
//    HoloKitDistortionRenderer_renderEyeToDisplay(
//        distortion_renderer_.get(), gl_framebuffer_id, screen_params_.x,
//        screen_params_.y, screen_params_.width, screen_params_.height,
//        &eye_data_[HoloKitEye::kLeft].texture,
//        &eye_data_[HoloKitEye::kRight].texture);
  }

  void RenderWidgets() {
    std::lock_guard<std::mutex> l(widget_mutex_);
    for (WidgetParams widget_param : widget_params_) {
      RenderWidget(widget_param);
    }
  }

  int GetLeftTextureId() {
    return gl_framebuffer_[HoloKitEye::kLeft].color_texture;
  }

  int GetRightTextureId() {
    return gl_framebuffer_[HoloKitEye::kRight].color_texture;
  }

  int GetLeftDepthBufferId() {
    return gl_framebuffer_[HoloKitEye::kLeft].depth_render_buffer;
  }

  int GetRightDepthBufferId() {
    return gl_framebuffer_[HoloKitEye::kRight].depth_render_buffer;
  }

  static void SetUnityScreenParams(int x, int y, int width, int height) {
    unity_screen_params_ = ScreenParams{x, y, width, height};
  }

  static void GetUnityScreenParams(int* width, int* height) {
    const ScreenParams screen_params = unity_screen_params_;
    *width = screen_params.width;
    *height = screen_params.height;
  }

  static void SetWidgetCount(int count) {
    std::lock_guard<std::mutex> l(widget_mutex_);
    widget_params_.resize(count);
  }

  static void SetWidgetParams(int i, const WidgetParams& params) {
    std::lock_guard<std::mutex> l(widget_mutex_);
    if (i < 0 || i >= widget_params_.size()) {
      LOGE("SetWidgetParams parameter i=%d, out of bounds (size=%d)",
           i, static_cast<int>(widget_params_.size()));
      return;
    }

    widget_params_[i] = params;
  }

  static void SetDeviceParametersChanged() { device_params_changed_ = true; }

  static bool GetDeviceParametersChanged() { return device_params_changed_; }

 private:
  // @brief Holds the rectangle information to draw into the screen.
  struct ScreenParams {
    // @brief x coordinate in pixels of the lower left corner of the rectangle.
    int x;

    // @brief y coordinate in pixels of the lower left corner of the rectangle.
    int y;

    // @brief The width of the rectangle in pixels.
    int width;

    // @brief The height of the rectangle in pixels.
    int height;
  };

  // @brief Holds eye information.
  struct EyeData {
    // @brief The eye-from-head homogeneous transformation for the eye.
    float eye_from_head_matrix[16];

    // @brief The field of view angles.
    // @details They are disposed as [left, right, bottom, top] and are in
    //          radians.
    float fov[4];

    // @brief HoloKit distortion mesh for the eye.
    HoloKitMesh distortion_mesh;

    // @brief HoloKit texture description for the eye.
    HoloKitEyeTextureDescription texture;
  };

  // @brief Holds the OpenGl texture, frame and depth buffers for each eye.
  struct GlFramebuffer {
    unsigned int color_texture = 0;

    unsigned int depth_render_buffer = 0;

    unsigned int frame_buffer = 0;
  };

  // @brief Custom deleter for HeadTracker.
  struct HoloKitHeadTrackerDeleter {
    void operator()(HoloKitHeadTracker* head_tracker) {
//      HoloKitHeadTracker_destroy(head_tracker);
    }
  };

  // @brief Custom deleter for DistortionRenderer.
  struct HoloKitDistortionRendererDeleter {
    void operator()(HoloKitDistortionRenderer* distortion_renderer) {
//      HoloKitDistortionRenderer_destroy(distortion_renderer);
    }
  };

  // @brief Computes the monotonic time in nano seconds.
  // @return The monotonic time count in nano seconds.
  static int64_t GetMonotonicTimeNano() {
    struct timespec res;
    clock_gettime(CLOCK_MONOTONIC, &res);
    return (res.tv_sec * HoloKitApi::HoloKitApiImpl::kNanosInSeconds) +
           res.tv_nsec;
  }

  // @brief Creates and configures a GlFramebuffer.
  //
  // @details Loads a color texture, then a depth buffer an finally a
  //          frame buffer for an eye.
  // @param gl_framebuffer A GlFramebuffer to load its resources.
//  void CreateGlFramebuffer(GlFramebuffer* gl_framebuffer) {
//    // Create color texture.
//    glGenTextures(1, &gl_framebuffer->color_texture);
//    glBindTexture(GL_TEXTURE_2D, gl_framebuffer->color_texture);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, screen_params_.width / 2,
//                 screen_params_.height, 0, GL_RGB, GL_UNSIGNED_BYTE, 0);
//    CHECKGLERROR("Create a color texture.");
//
//    // Create depth buffer.
//    glGenRenderbuffers(1, &gl_framebuffer->depth_render_buffer);
//    glBindRenderbuffer(GL_RENDERBUFFER, gl_framebuffer->depth_render_buffer);
//    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16,
//                          screen_params_.width / 2, screen_params_.height);
//    CHECKGLERROR("Create depth render buffer.");
//
//    // Create a frame buffer
//    glGenFramebuffers(1, &gl_framebuffer->frame_buffer);
//    glBindFramebuffer(GL_FRAMEBUFFER, gl_framebuffer->frame_buffer);
//    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
//                           gl_framebuffer->color_texture, 0);
//    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
//                              GL_RENDERBUFFER,
//                              gl_framebuffer->depth_render_buffer);
//    CHECKGLERROR("Create frame buffer.");
//  }

  // @brief Configures GL resources.
//  void GlSetup() {
//    if (gl_framebuffer_[0].frame_buffer != 0) {
//      GlTeardown();
//    }
//
//    // Create render texture, depth buffer and frame buffer for both eyes.
//    CreateGlFramebuffer(&gl_framebuffer_[HoloKitEye::kLeft]);
//    CreateGlFramebuffer(&gl_framebuffer_[HoloKitEye::kRight]);
//
//    eye_data_[HoloKitEye::kLeft].texture.texture =
//        gl_framebuffer_[HoloKitEye::kLeft].color_texture;
//    eye_data_[HoloKitEye::kLeft].texture.left_u = 0;
//    eye_data_[HoloKitEye::kLeft].texture.right_u = 1;
//    eye_data_[HoloKitEye::kLeft].texture.top_v = 1;
//    eye_data_[HoloKitEye::kLeft].texture.bottom_v = 0;
//
//    eye_data_[HoloKitEye::kRight].texture.texture =
//        gl_framebuffer_[HoloKitEye::kRight].color_texture;
//    eye_data_[HoloKitEye::kRight].texture.left_u = 0;
//    eye_data_[HoloKitEye::kRight].texture.right_u = 1;
//    eye_data_[HoloKitEye::kRight].texture.top_v = 1;
//    eye_data_[HoloKitEye::kRight].texture.bottom_v = 0;
//
//    // Load widget state
//    widget_program_ = CreateProgram(kWidgetVertexShader, kWidgetFragmentShader);
//    widget_attrib_position_ = glGetAttribLocation(widget_program_, "aPosition");
//    widget_attrib_tex_coords_ = glGetAttribLocation(widget_program_,
//                                                    "aTexCoords");
//    widget_uniform_texture_ = glGetUniformLocation(widget_program_, "uTexture");
//  }

  // @brief Releases Gl resources in a GlFramebuffer.
  //
  // @param gl_framebuffer A GlFramebuffer to release its resources.
//  void DestroyGlFramebuffer(GlFramebuffer* gl_framebuffer) {
//    glDeleteRenderbuffers(1, &gl_framebuffer->depth_render_buffer);
//    gl_framebuffer->depth_render_buffer = 0;
//
//    glDeleteFramebuffers(1, &gl_framebuffer->frame_buffer);
//    gl_framebuffer->frame_buffer = 0;
//
//    glDeleteTextures(1, &gl_framebuffer->color_texture);
//    gl_framebuffer->color_texture = 0;
//  }

  // @brief Frees GL resources.
  void GlTeardown() {
//    if (gl_framebuffer_[0].frame_buffer == 0) {
//      return;
//    }
//    DestroyGlFramebuffer(&gl_framebuffer_[HoloKitEye::kLeft]);
//    DestroyGlFramebuffer(&gl_framebuffer_[HoloKitEye::kRight]);
//    CHECKGLERROR("GlTeardown");
  }

  static constexpr float Lerp(float start, float end, float val) {
    return start + (end - start) * val;
  }

  void RenderWidget(WidgetParams params) {
//    glBindBuffer(GL_ARRAY_BUFFER, 0);
//    glDisable(GL_CULL_FACE);
//    glEnable(GL_BLEND);
//    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//    glBlendEquation(GL_FUNC_ADD);
//
//    // Convert coordinates to normalized space (-1,-1 - +1,+1)
//    float x = Lerp(-1, +1, static_cast<float>(params.x) / screen_params_.width);
//    float y = Lerp(-1, +1, static_cast<float>(params.y) / screen_params_.height);
//    float width = params.width * 2.0f / screen_params_.width;
//    float height = params.height * 2.0f / screen_params_.height;
//
//    const float position[] =
//      { x, y, x + width, y, x, y + height, x + width, y + height };
//    glEnableVertexAttribArray(widget_attrib_position_);
//    glVertexAttribPointer(
//        widget_attrib_position_, /*size=*/2, /*type=*/GL_FLOAT,
//        /*normalized=*/GL_FALSE, /*stride=*/0, /*pointer=*/position);
//
//    const float uv[] = { 0, 0, 1, 0, 0, 1, 1, 1 };
//    glEnableVertexAttribArray(widget_attrib_tex_coords_);
//    glVertexAttribPointer(
//        widget_attrib_tex_coords_, /*size=*/2, /*type=*/GL_FLOAT,
//        /*normalized=*/GL_FALSE, /*stride=*/0, /*pointer=*/uv);
//
//    glUseProgram(widget_program_);
//
//    glActiveTexture(GL_TEXTURE0);
//    glBindTexture(GL_TEXTURE_2D, params.texture);
//    glUniform1i(widget_uniform_texture_, 0);
//
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//
//    CHECKGLERROR("RenderWidget");
  }

  // @brief Default prediction excess time in nano seconds.
  static constexpr int64_t kPredictionTimeWithoutVsyncNanos = 50000000;

  // @brief Default z-axis coordinate for the near clipping plane.
  static constexpr float kZNear = 0.1f;

  // @brief Default z-axis coordinate for the far clipping plane.
  static constexpr float kZFar = 10.0f;

  // @brief Constant to convert seconds into nano seconds.
  static constexpr int64_t kNanosInSeconds = 1000000000;

  // @brief HeadTracker native pointer.
  std::unique_ptr<HoloKitHeadTracker, HoloKitHeadTrackerDeleter>
      head_tracker_;

  // @brief DistortionRenderer native pointer.
  std::unique_ptr<HoloKitDistortionRenderer,
                  HoloKitDistortionRendererDeleter>
      distortion_renderer_;

  // @brief Screen parameters.
  ScreenParams screen_params_;

  // @brief Eye data information.
  // @details `HoloKitEye::kLeft` index holds left eye data and
  //          `HoloKitEye::kRight` holds the right eye data.
  std::array<EyeData, 2> eye_data_;

  // @brief Holds the OpenGL framebuffer information for each eye.
  std::array<GlFramebuffer, 2> gl_framebuffer_;

  // @brief Store Unity reported screen params.
  static std::atomic<ScreenParams> unity_screen_params_;

  // @brief Unity-loaded widgets
  static std::vector<WidgetParams> widget_params_;

  // @brief Mutex for widget_params_ access.
  static std::mutex widget_mutex_;

  // @brief RenderWidget GL program.
//  GLuint widget_program_;

  // @brief RenderWidget "aPosition" attrib location.
//  GLint widget_attrib_position_;

  // @brief RenderWidget "aTexCoords" attrib location.
//  GLint widget_attrib_tex_coords_;

  // @brief RenderWidget "uTexture" uniform location.
//  GLint widget_uniform_texture_;

  // @brief Track changes to device parameters.
  static std::atomic<bool> device_params_changed_;
};

std::atomic<HoloKitApi::HoloKitApiImpl::ScreenParams>
    HoloKitApi::HoloKitApiImpl::unity_screen_params_({0, 0});

std::vector<HoloKitApi::WidgetParams>
    HoloKitApi::HoloKitApiImpl::widget_params_;

std::mutex HoloKitApi::HoloKitApiImpl::widget_mutex_;

std::atomic<bool> HoloKitApi::HoloKitApiImpl::device_params_changed_(true);

HoloKitApi::HoloKitApi() { p_impl_.reset(new HoloKitApiImpl()); }

HoloKitApi::~HoloKitApi() = default;

void HoloKitApi::InitHeadTracker() { p_impl_->InitHeadTracker(); }

void HoloKitApi::PauseHeadTracker() { p_impl_->PauseHeadTracker(); }

void HoloKitApi::ResumeHeadTracker() { p_impl_->ResumeHeadTracker(); }

void HoloKitApi::GetHeadTrackerPose(float* position, float* orientation) {
  p_impl_->GetHeadTrackerPose(position, orientation);
}

void HoloKitApi::ScanDeviceParams() { HoloKitApiImpl::ScanDeviceParams(); }

void HoloKitApi::UpdateDeviceParams() { p_impl_->UpdateDeviceParams(); }

void HoloKitApi::GetEyeMatrices(int eye, float* eye_from_head, float* fov) {
  return p_impl_->GetEyeMatrices(eye, eye_from_head, fov);
}

void HoloKitApi::RenderEyesToDisplay(int gl_framebuffer_id) {
  p_impl_->RenderEyesToDisplay(gl_framebuffer_id);
}

void HoloKitApi::RenderWidgets() {
  p_impl_->RenderWidgets();
}

int HoloKitApi::GetLeftTextureId() { return p_impl_->GetLeftTextureId(); }

int HoloKitApi::GetRightTextureId() { return p_impl_->GetRightTextureId(); }

int HoloKitApi::GetLeftDepthBufferId() {
  return p_impl_->GetLeftDepthBufferId();
}

int HoloKitApi::GetRightDepthBufferId() {
  return p_impl_->GetRightDepthBufferId();
}

int HoloKitApi::GetBoundFramebuffer() {
  int bound_framebuffer = 0;
//  glGetIntegerv(GL_FRAMEBUFFER_BINDING, &bound_framebuffer);
  return bound_framebuffer;
}

void HoloKitApi::GetScreenParams(int* width, int* height) {
  HoloKitApi::HoloKitApiImpl::GetUnityScreenParams(width, height);
}

void HoloKitApi::SetUnityScreenParams(int x, int y, int width, int height) {
  HoloKitApi::HoloKitApiImpl::SetUnityScreenParams(x, y, width, height);
}

void HoloKitApi::SetDeviceParametersChanged() {
  HoloKitApi::HoloKitApiImpl::SetDeviceParametersChanged();
}

bool HoloKitApi::GetDeviceParametersChanged() {
  return HoloKitApi::HoloKitApiImpl::GetDeviceParametersChanged();
}

void HoloKitApi::SetWidgetCount(int count) {
  HoloKitApi::HoloKitApiImpl::SetWidgetCount(count);
}

void HoloKitApi::SetWidgetParams(int i, const WidgetParams& params) {
  HoloKitApi::HoloKitApiImpl::SetWidgetParams(i, params);
}

}  // namespace unity
}  // namespace holokit

#ifdef __cplusplus
extern "C" {
#endif

void HoloKitUnity_setScreenParams(int x, int y, int width, int height) {
  holokit::unity::HoloKitApi::SetUnityScreenParams(x, y, width, height);
}

void HoloKitUnity_setDeviceParametersChanged() {
  holokit::unity::HoloKitApi::SetDeviceParametersChanged();
}

void HoloKitUnity_setWidgetCount(int count) {
  holokit::unity::HoloKitApi::SetWidgetCount(count);
}

void HoloKitUnity_setWidgetParams(int i, void* texture, int x, int y,
                                    int width, int height) {
  holokit::unity::HoloKitApi::WidgetParams params;

  params.texture = static_cast<int>(reinterpret_cast<intptr_t>(texture));
  params.x = x;
  params.y = y;
  params.width = width;
  params.height = height;
  holokit::unity::HoloKitApi::SetWidgetParams(i, params);
}

#ifdef __cplusplus
}
#endif
