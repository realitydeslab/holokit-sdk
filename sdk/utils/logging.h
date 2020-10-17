
#ifndef HOLOKIT_SDK_UTIL_LOGGING_H_
#define HOLOKIT_SDK_UTIL_LOGGING_H_

#if defined(__APPLE__)

#import <os/log.h>

#define HOLOKIT_LOGI(...) os_log_info(OS_LOG_DEFAULT, __VA_ARGS__)
#define HOLOKIT_LOGE(...) os_log_error(OS_LOG_DEFAULT, __VA_ARGS__)

#elif defined(__ANDROID__)

#include <android/log.h>

#define HOLOKIT_LOGI(...) \
  __android_log_print(ANDROID_LOG_INFO, "HoloKitSDK", __VA_ARGS__)
#define HOLOKIT_LOGE(...) \
  __android_log_print(ANDROID_LOG_ERROR, "HoloKitSDK", __VA_ARGS__)

#else

#define HOLOKIT_LOGI(...)
#define HOLOKIT_LOGE(...)

#endif

#endif  // HOLOKIT_SDK_UTIL_LOGGING_H_
