//
//  holokit_xr_unity.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/3/29.
//

#include "UnityXRTypes.h"

namespace holokit {
    
/// Wrapper of HoloKit SDK
class HoloKitApi {
public:
    /// @brief Constructs a HoloKitApi.
    HoloKitApi();
    
    /// @brief Destructor.
    ~HoloKitApi();
    
    UnityXRPose GetViewMatrix(int eye_index);
    
    UnityXRMatrix4x4 GetProjectionMatrix(int eye_index);
    
    UnityXRRectf GetViewportRect(int eye_index);
    
private:

};
}
