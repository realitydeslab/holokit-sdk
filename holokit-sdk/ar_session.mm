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
#import "math_helpers.h"

typedef void (*DidAddARParticipantAnchor)();
DidAddARParticipantAnchor DidAddARParticipantAnchorDelegate = NULL;

typedef void (*ARSessionDidStart)();
ARSessionDidStart ARSessionDidStartDelegate = NULL;

typedef void (*DidReceiveMagicAnchor)(int clientId, int magicIndex, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float rotW);
DidReceiveMagicAnchor DidReceiveMagicAnchorDelegate = NULL;

typedef void (*ThermalStateDidChange)(int state);
ThermalStateDidChange ThermalStateDidChangeDelegate = NULL;

@interface HoloKitARSession() <ARSessionDelegate>

@property (assign) BOOL isSynchronizationComplete;
@property (nonatomic, strong) ARAnchor *originAnchor;
@property (nonatomic, strong) NSUUID *currentARSessionId;

@end

@implementation HoloKitARSession

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        // https://developer.apple.com/videos/play/wwdc2021/10147/
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self
                                                          selector:@selector(displayLinkCallback:)];
        //[link setPreferredFramesPerSecond:60];
        [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        self.isSynchronizationComplete = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thermalStateDidChange) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    }
    return self;
}

// https://developer.apple.com/videos/play/wwdc2021/10147/
- (void)displayLinkCallback:(CADisplayLink *)link {
    self.lastVsyncTimestamp = link.timestamp;
    self.nextVsyncTimestamp = link.targetTimestamp;

//    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
//    os_signpost_id_t spid = os_signpost_id_generate(log);
//    os_signpost_interval_begin(log, spid, "CADisplayLink");
//    os_signpost_interval_end(log, spid, "CADisplayLink");
}

- (void)thermalStateDidChange {
    if (ThermalStateDidChangeDelegate == NULL) {
        return;
    }
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    switch(thermalState) {
        case NSProcessInfoThermalStateNominal:
            ThermalStateDidChangeDelegate(0);
            break;
        case NSProcessInfoThermalStateFair:
            ThermalStateDidChangeDelegate(1);
            break;
        case NSProcessInfoThermalStateSerious:
            ThermalStateDidChangeDelegate(2);
            break;
        case NSProcessInfoThermalStateCritical:
            ThermalStateDidChangeDelegate(3);
            break;
    }
}

+ (id)sharedARSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)updateWithCollaborationData:(ARCollaborationData *)collaborationData {
    [self.arSession updateWithCollaborationData:collaborationData];
}

- (void)removeAllLocalAnchors {
    for (ARAnchor *anchor in self.arSession.currentFrame.anchors) {
        if ([anchor.identifier isEqual:self.arSession.identifier]) {
            [self.arSession removeAnchor:anchor];
        }
    }
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    //    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    //    os_signpost_id_t spid = os_signpost_id_generate(log);
    //    os_signpost_interval_begin(log, spid, "Update ARKit");
    
    if(![self.currentARSessionId isEqual:session.identifier]) {
        NSLog(@"[ar_session] ARSession did update");
        self.arSession = session;
        self.currentARSessionId = session.identifier;
        if (ARSessionDidStartDelegate != NULL) {
            ARSessionDidStartDelegate();
            [self.multipeerSession sendARSessionId2AllPeers];
        }
    }
    
    if (holokit::LowLatencyTrackingApi::GetInstance()->IsActive()) {
        holokit::ARKitData data = { frame.timestamp,
            TransformToEigenVector3d(frame.camera.transform),
            TransformToEigenQuaterniond(frame.camera.transform),
            MatrixToEigenMatrix3d(frame.camera.intrinsics) };
        holokit::LowLatencyTrackingApi::GetInstance()->OnARKitDataUpdated(data);
    }
    
    //NSLog(@"[ar_session]: current number of anchors %lu", (unsigned long)frame.anchors.count);
    
    //os_signpost_interval_end(log, spid, "Update ARKit");
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
    }

    for (ARAnchor *anchor in anchors) {
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            if (DidAddARParticipantAnchorDelegate != NULL) {
                DidAddARParticipantAnchorDelegate();
            }
            else {
                NSLog(@"[ar_session] DidAddARParticipantAnchorDelegate is NULL");
            }
            NSLog(@"[ar_session] did add an ARParticipantAnchor");
            continue;
        }
        if (anchor.name != nil) {
            if (![self.multipeerSession isHost] && [anchor.name isEqualToString:@"origin"]) {
                NSLog(@"[ar_session] did receive an origin anchor.");
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
}
    
- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didRemoveAnchors:anchors];
    }
    for (ARAnchor *anchor in anchors) {
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            NSLog(@"[ar_session] did remove an ARParticipantAnchor");
        }
        if ([anchor.name isEqualToString:@"origin"]) {
            NSLog(@"[ar_session] did remove an origin anchor");
        }
    }
}

- (void)session:(ARSession *)session didOutputCollaborationData:(ARCollaborationData *)data {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    
    if (self.multipeerSession == nil) {
        return;
    }
    if (self.multipeerSession.mcSession.connectedPeers.count == 0) {
        return;
    }
    // TEST: 'requiringSecureCoding' used to be YES.
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:NO error:nil];
    if (data.priority == ARCollaborationDataPriorityCritical) {
        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
    } else {
        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
    }
    
//    if (!self.isSynchronizationComplete) {
//        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
//    } else {
//        if (data.priority == ARCollaborationDataPriorityCritical) {
//            [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
//        } else {
//            [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
//        }
//    }
}

#pragma mark - ARSessionObserver

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    switch (camera.trackingState) {
        case ARTrackingStateNotAvailable:
            NSLog(@"[ar_session] AR tracking state changed to not available.");
            break;
        case ARTrackingStateLimited:
            NSLog(@"[ar_session] AR tracking state changed to limited, and the reason is:");
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ar_session] None");
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ar_session] Initializing");
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ar_session] Excessive motion");
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ar_session] Insufficient features");
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ar_session] Relocalizing");
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ar_session] AR tracking state changed to normal.");
            break;
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"[ar_session] session was interrupted.");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"[ar_session] session interruption ended.");
}

- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session {
    return true;
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
    
    ARSession* sessionPtr = (__bridge ARSession*)ar_native_session->sessionPtr;
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    ar_session.unityARSessionDelegate = sessionPtr.delegate;
    
    [sessionPtr setDelegate:ar_session];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    [ar_session.arSession setWorldOrigin:(transform_matrix)];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_AddNativeAnchor(const char * anchorName, float position[3], float rotation[4]) {
    HoloKitARSession *session = [HoloKitARSession sharedARSession];
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    std::vector<float> rot = SimdFloat4x42UnityRotation(transform_matrix);
    NSString *name = [NSString stringWithUTF8String:anchorName];
    if ([name isEqualToString:@"origin"]){
        // Do not accumulate anchors.
        if (session.originAnchor != nil) {
            [session.arSession removeAnchor:session.originAnchor];
        }
        session.originAnchor = [[ARAnchor alloc] initWithName:name transform:transform_matrix];
        [session.arSession addAnchor:session.originAnchor];
    } else {
        ARAnchor* anchor = [[ARAnchor alloc] initWithName:name transform:transform_matrix];
        [session.arSession addAnchor:anchor];
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidAddARParticipantAnchorDelegate(DidAddARParticipantAnchor callback) {
    DidAddARParticipantAnchorDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSessionDidStartDelegate(ARSessionDidStart callback) {
    ARSessionDidStartDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveMagicAnchorDelegate(DidReceiveMagicAnchor callback) {
    DidReceiveMagicAnchorDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetThermalStateDidChangeDelegate(ThermalStateDidChange callback) {
    ThermalStateDidChangeDelegate = callback;
}

int UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_GetThermalState() {
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    switch(thermalState) {
        case NSProcessInfoThermalStateNominal:
            return 0;
            break;
        case NSProcessInfoThermalStateFair:
            return 1;
            break;
        case NSProcessInfoThermalStateSerious:
            return 2;
            break;
        case NSProcessInfoThermalStateCritical:
            return 3;
            break;
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SynchronizationComplete() {
    NSLog(@"[ar_session] Synchronization complete");
    [[HoloKitARSession sharedARSession] setIsSynchronizationComplete:YES];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_RemoveAllLocalAnchors() {
    [[HoloKitARSession sharedARSession] removeAllLocalAnchors];
}

} // extern "C"
