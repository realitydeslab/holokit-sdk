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

typedef void (*ARWorldMapSynced)();
ARWorldMapSynced ARWorldMapSyncedDelegate = NULL;

typedef void (*DidUpdateARParticipantAnchor)(float *position, float *rotation);
DidUpdateARParticipantAnchor DidUpdateARParticipantAnchorDelegate = NULL;

@interface HoloKitARSession() <ARSessionDelegate>

@property (nonatomic, assign) bool isSynced;
@property (nonatomic, assign) bool shareARCollaborationData;
@property (nonatomic, assign) int criticalDataCount;
@property (nonatomic, assign) int optionalDataCount;

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
        
        self.isSynced = NO;
        self.shareARCollaborationData = YES;
        self.criticalDataCount = 0;
        self.optionalDataCount = 0;
        
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
    
    //    os_log_t log = os_log_create("com.HoloInteractive.TheMagic", OS_LOG_CATEGORY_POINTS_OF_INTEREST);
    //    os_signpost_id_t spid = os_signpost_id_generate(log);
    //    os_signpost_interval_begin(log, spid, "Update ARKit");
    
    if(self.arSession == NULL) {
        NSLog(@"[ar_session]: AR session started.");
        self.arSession = session;
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
    //NSLog(@"[ar_session]: did add anchors");
    for (ARAnchor *anchor in anchors) {
        // Check if this anchor is a new peer
        //NSLog(@"[ar_session]: received an anchor with name %@", anchor.name);
        LogMatrix4x4(anchor.transform);
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            NSLog(@"[ar_session]: a new peer is connected to the AR collaboration session.");
            // Let the ARWorldOriginManager know that AR collaboration session has started.
            if (ARWorldMapSyncedDelegate != NULL) {
                ARWorldMapSyncedDelegate();
            }
            NSLog(@"[ar_session]: ar participant anchor transform %f, %f, %f", [(ARParticipantAnchor*)anchor transform].columns[3].x, anchor.transform.columns[3].y, anchor.transform.columns[3].z);
            self.isSynced = YES;
            continue;
        }
        if (anchor.name != nil) {
            if (![self.multipeerSession isHost] && [anchor.name isEqual:@"-1"]) {
                // This is an origin anchor.
                // If this is a client, reset the world origin.
                NSLog(@"[ar_session]: Did receive an origin anchor, reset the world origin.");
//                std::vector<float> position = TransformToUnityPosition(anchor.transform);
//                std::vector<float> rotation = TransformToUnityRotation(anchor.transform);
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
    //NSLog(@"[ar_session]: did remove anchoors");
}

- (void)session:(ARSession *)session didOutputCollaborationData:(ARCollaborationData *)data {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    
    if (!self.shareARCollaborationData) {
        return;
    }
    if (self.multipeerSession == nil) {
        return;
    }
    if (self.multipeerSession.connectedPeersForUnity.count == 0) {
        return;
    }
    // TEST: 'requiringSecureCoding' used to be YES.
    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:NO error:nil];
    if (data.priority == ARCollaborationDataPriorityCritical) {
        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
        //NSLog(@"[ar_session]: critical ar collaboration data %d", ++self.criticalDataCount);
    } else {
        [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
        //NSLog(@"[ar_session]: optional ar collaboration data %d", ++self.optionalDataCount);
    }
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
    
    ARSession* sessionPtr = (__bridge ARSession*) ar_native_session->sessionPtr;
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    ar_session.unityARSessionDelegate = sessionPtr.delegate;
    
    [sessionPtr setDelegate:ar_session];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = TransformFromUnity(position, rotation);
    
    HoloKitARSession* ar_session = [HoloKitARSession sharedARSession];
    [ar_session.arSession setWorldOrigin:(transform_matrix)];
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
UnityHoloKit_EnableShareARCollaborationData(bool val) {
    [[HoloKitARSession sharedARSession] setShareARCollaborationData:val];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidUpdateARParticipantAnchorDelegate(DidUpdateARParticipantAnchor callback) {
    DidUpdateARParticipantAnchorDelegate = callback;
}

} // extern "C"
