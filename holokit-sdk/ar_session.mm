//
//  ar_session.mm
//  test-unity-input-ios
//
//  Created by Yuchen on 2021/3/6.
//

#import "ar_session.h"
#import "UnityXRNativePtrs.h"
#import <TargetConditionals.h>
#import "UnityXRTypes.h"
#import "IUnityInterface.h"
#import "XR/UnitySubsystemTypes.h"

#import <os/log.h>
#import <os/signpost.h>
#import <vector>

//#if TARGET_OS_IPHONE
#import "low-latency-tracking/low_latency_tracking_api.h"
#import "holokit_api.h"
#import "core_motion.h"

typedef void (*ARWorldMapSynced)();
ARWorldMapSynced ARWorldMapSyncedDelegate = NULL;

@interface HoloKitARSession() <ARSessionDelegate>
 
@end

@implementation HoloKitARSession

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        // Metal Vsync
        //NSLog(@"number of screens: %lu", (unsigned long)[[UIScreen screens] count]);
        //NSLog(@"Maximum FPS = %ld", [UIScreen mainScreen].maximumFramesPerSecond);
        self.aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(printNextVsyncTime)];
        //[aDisplayLink setFrameInterval:animationFrameInterval];
        [self.aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        self.appleWatchIsTracked = NO;
    }
    return self;
}

- (void)printNextVsyncTime {
    //NSLog(@"currentime: %f, vsync time: %f", [[NSProcessInfo processInfo] systemUptime], [self.aDisplayLink targetTimestamp]);
}

+ (id)sharedARSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)updateWithHoloKitCollaborationData:(ARCollaborationData *)collaborationData {
    [self.arSession updateWithCollaborationData:collaborationData];
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    if(self.arSession == NULL) {
        NSLog(@"[ar_session]: AR session started.");
        self.arSession = session;
        
        //holokit::LowLatencyTrackingApi::GetInstance()->Activate();
        //[[HoloKitCoreMotion sharedCoreMotion] startAccelerometer];
        //[[HoloKitCoreMotion sharedCoreMotion] startGyroscope];
        //[[HoloKitCoreMotion sharedCoreMotion] startDeviceMotion];
    }
    
//    holokit::ARKitData data = { frame.timestamp,
//        TransformToEigenVector3d(frame.camera.transform),
//        TransformToEigenQuaterniond(frame.camera.transform),
//        MatrixToEigenMatrix3d(frame.camera.intrinsics) };
//    holokit::LowLatencyTrackingApi::GetInstance()->OnARKitDataUpdated(data);
    
    // If hands are lost.
    // This is only useful for Google Mediapipe hand tracking.
//    if (self.isLeftHandTracked || self.isRightHandTracked) {
//        float currentTimestamp = [[NSProcessInfo processInfo] systemUptime];
//        if((currentTimestamp - self.lastHandTrackingTimestamp) > kLostHandTrackingInterval) {
//            NSLog(@"[ar_session]: hand tracking lost.");
//            self.isLeftHandTracked = false;
//            self.isRightHandTracked = false;
//        }
//    }
    
    // Hand tracking
//    self.frameCount++;
//    if (self.isHandTrackingEnabled && self.frameCount % self.handPosePredictionInterval == 0) {
//
//        [self.handTrackingQueue addOperationWithBlock:^{
//            [self.handTracker processVideoFrame: frame.capturedImage];
//        }];
//
//        [self performHumanHandPoseRequest:frame];
//    }
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
    }
    for (ARAnchor *anchor in anchors) {
        // Check if this anchor is a new peer
        //NSLog(@"[ar_session]: received an anchor with name %@", anchor.name);
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            NSLog(@"[ar_session]: a new peer is connected to the AR collaboration session.");
            // Let the ARWorldOriginManager know that AR collaboration session has started.
            ARWorldMapSyncedDelegate();
            continue;
        }
        if (anchor.name != nil) {
            if (![self.multipeerSession isHost] && [anchor.name isEqual:@"-1"]) {
                // This is an origin anchor.
                // If this is a client, reset the world origin.
                NSLog(@"[ar_session]: Did receive an origin anchor, reset the world origin.");
                std::vector<float> position = TransformToUnityPosition(anchor.transform);
                std::vector<float> rotation = TransformToUnityRotation(anchor.transform);
                [session setWorldOrigin:anchor.transform];
                continue;
            }
        }
    }
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateAnchors:anchors];
    }
    //NSLog(@"[ar_session]: didUpdateAnchors()");
}
    
- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didRemoveAnchors:anchors];
    }
}

- (void)session:(ARSession *)session didOutputCollaborationData:(ARCollaborationData *)data {
    //NSLog(@"[ar_session]: did output ARCollaboration data.");
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    if (self.multipeerSession == nil) {
        return;
    }
    if (self.multipeerSession.connectedPeersForMLAPI.count == 0) {
        return;
    }
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:nil];
    [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
    
//    if (data.priority == ARCollaborationDataPriorityCritical) {
//        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
//    } else {
//        //[self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
//    }
    
}

#pragma mark - ARSessionObserver

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    switch (camera.trackingState) {
        case ARTrackingStateNotAvailable:
            NSLog(@"[ar_session]: AR tracking state changed to not available.");
            break;
        case ARTrackingStateLimited:
            NSLog(@"[ar_session]: AR tracking state changed to limited, and the reason is:");
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ar_session]: None");
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ar_session]: Initializing");
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ar_session]: Excessive motion");
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ar_session]: Insufficient features");
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ar_session]: Relocalizing");
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ar_session]: AR tracking state changed to normal.");
            break;
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"[ar_session]: session was interrupted.");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"[ar_session]: session interruption ended.");
}

@end

#pragma mark - extern "C"

extern "C" {

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    if (ar_native_session == nullptr) {
        NSLog(@"[ar_session]: native ARSession is NULL.");
        return;
    }
    
    ARSession* sessionPtr = (__bridge ARSession*) ar_native_session->sessionPtr;
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    ar_session.unityARSessionDelegate = sessionPtr.delegate;
    
    [sessionPtr setDelegate:ar_session];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = TransformFromUnity(position, rotation);
    
    HoloKitARSession* ar_session_handler = [HoloKitARSession sharedARSession];
    [ar_session_handler.arSession setWorldOrigin:(transform_matrix)];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_AddNativeAnchor(const char * anchorName, float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = TransformFromUnity(position, rotation);
    ARAnchor* anchor = [[ARAnchor alloc] initWithName:[NSString stringWithUTF8String:anchorName] transform:transform_matrix];
    
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    [ar_session.arSession addAnchor:anchor];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARWorldMapSyncedDelegate(ARWorldMapSynced callback) {
    ARWorldMapSyncedDelegate = callback;
}

} // extern "C"
