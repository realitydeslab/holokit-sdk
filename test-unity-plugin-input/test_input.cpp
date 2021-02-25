//
//  test_input.cpp
//  test-unity-plugin-input
//
//  Created by Yuchen on 2021/2/25.
//

#include <time.h>

#include <array>
#include <cmath>

#include "IUnityInterface.h"
#include "IUnityXRInput.h"
#include "IUnityXRTrace.h"
#include "UnitySubsystemTypes.h"

#define HOLOKIT_INPUT_XR_TRACE_LOG(trace, message, ...)                \
  XR_TRACE_LOG(trace, "[HoloKitXrInputProvider]: " message "\n", \
               ##__VA_ARGS__)

namespace {

class HoloKitInputProvider {
public:
    HoloKitInputProvider(IUnityXRTrace* trace, IUnityXRInputInterface* input)
    : trace_(trace), input_(input) {
        // holokit_api_.reset(new holokit::unity::HoloKitApi());
    }
    
    IUnityXRInputInterface* GetInput() { return input_; }
    
    IUnityXRTrace* GetTrace() { return trace_; }
    
    static std::unique_ptr<HoloKitInputProvider>& GetInstance();
    
private:
    static constexpr int kDeviceIdHoloKitHme = 0;
    static constexpr int kDeviceIdHoloKitTrackedHand = 1;
    
    static constexpr UnityXRInputDeviceCharacteristics kHmeCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
            kUnityXRInputDeviceCharacteristicsHeadMounted |
            kUnityXRInputDeviceCharacteristicsTrackedDevice);
    
    static constexpr UnityXRInputDeviceCharacteristics kTrackedHandCharacteristics =
        static_cast<UnityXRInputDeviceCharacteristics>(
            kUnityXRInputDeviceCharacteristicsHandTracking);
    
    IUnityXRTrace* trace_ = nullptr;
    
    IUnityXRInputInterface* input_ = nullptr;
    
    UnityXRPose head_pose_;
    
    // define holokit_api_
    
    static std::unique_ptr<HoloKitInputProvider> holokit_input_provider_;
};

std::unique_ptr<HoloKitInputProvider> HoloKitInputProvider::holokit_input_provider_;

std::unique_ptr<HoloKitInputProvider>& HoloKitInputProvider::GetInstance() {
    return holokit_input_provider_;
}

} // namespace

