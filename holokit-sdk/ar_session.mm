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
#import "holokit_api.h"
#import "math_helpers.h"

// For testing purpose
#import <os/log.h>
#import <os/signpost.h>

typedef void (*DidAddARParticipantAnchor)();
DidAddARParticipantAnchor DidAddARParticipantAnchorDelegate = NULL;

typedef void (*ARSessionDidUpdate)();
ARSessionDidUpdate ARSessionDidUpdateDelegate = NULL;

typedef void (*ThermalStateDidChange)(int state);
ThermalStateDidChange ThermalStateDidChangeDelegate = NULL;

typedef void (*CameraDidChangeTrackingState)(int trackingState);
CameraDidChangeTrackingState CameraDidChangeTrackingStateDelegate = NULL;

typedef void (*ARWorldMappingStatusDidChange)(int status);
ARWorldMappingStatusDidChange ARWorldMappingStatusDidChangeDelegate = NULL;

typedef void (*DidFindARWorldMap)(const char *mapName);
DidFindARWorldMap DidFindARWorldMapDelegate = NULL;

typedef void (*DidSaveARWorldMap)(const char *mapName);
DidSaveARWorldMap DidSaveARWorldMapDelegate = NULL;

@interface ARSessionDelegateController() <ARSessionDelegate>

@property (assign) ARWorldMappingStatus currentARWorldMappingStatus;
@property (assign) BOOL sessionShouldAttemptRelocalization;

@end

@implementation ARSessionDelegateController

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        self.scanEnvironment = NO;
        self.currentARWorldMappingStatus = ARWorldMappingStatusNotAvailable;
        
        self.sessionShouldAttemptRelocalization = false;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(thermalStateDidChange) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    }
    return self;
}

+ (id)sharedARSessionDelegateController {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)thermalStateDidChange {
    if (ThermalStateDidChangeDelegate) {
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

- (void)saveARWorldMap:(NSString *)mapName {
    if (self.currentARWorldMappingStatus != ARWorldMappingStatusMapped) {
        NSLog(@"[world_map] ARWorldMap is currently not available");
        return;
    }

    [self.arSession getCurrentWorldMapWithCompletionHandler:^(ARWorldMap * _Nullable worldMap, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[world_map] failed to get ARWorldMap");
            return;
        }
        
        NSLog(@"[world_map] started to save ARWorldMap");
        double startTime = [[NSProcessInfo processInfo] systemUptime];
        // Serialize map data
        NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:worldMap requiringSecureCoding:NO error:nil];
        // Create map folder if necessary
        NSString *directoryPath = [NSString stringWithFormat:@"%@%@", NSHomeDirectory(), @"/Documents/Maps/"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath]) {
            NSLog(@"[File] create directory %@", directoryPath);
            [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        // Generate map file path
        NSString *filePath = [NSString stringWithFormat:@"%@%@%@", directoryPath, mapName, @".arexperience"];
        // Save map data to the path
        [mapData writeToFile:filePath atomically:YES];
        NSLog(@"[world_map] saved ARWorldMap in %f", [[NSProcessInfo processInfo] systemUptime] - startTime);
        NSLog(@"[world_map] map name: %@\nmap size: %f mb\nmap path: %@", mapName, mapData.length / (1024.0 * 1024.0), filePath);
        
        if (DidSaveARWorldMapDelegate) {
            DidSaveARWorldMapDelegate([mapName UTF8String]);
        }
    }];
}

- (BOOL)retrieveARWorldMap:(NSString *)mapName {
    NSString *filePath = [NSString stringWithFormat:@"%@%@%@%@", NSHomeDirectory(), @"/Documents/Maps/", mapName, @".arexperience"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *mapData = [[NSData alloc] initWithContentsOfFile:filePath];
        ARWorldMap *worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:mapData error:nil];
        if (worldMap == nil) {
            NSLog(@"[world_map] failed to decode ARWorldMap data");
            return NO;
        }
        NSLog(@"[world_map] did retrieve ARWorldMap of size %f mb at path %@", mapData.length / (1024.0 * 1024.0), filePath);
        self.worldMap = worldMap;
        return YES;
    } else {
        NSLog(@"[world_map] failed to find map file at %@", filePath);
        return NO;
    }
}

- (void)loadARWorldMap {
    if (self.worldMap == nil) {
        NSLog(@"[world_map] there is no local ARWorldMap to load");
        return;
    }
    
    ARSession *arSession = [[ARSessionDelegateController sharedARSessionDelegateController] arSession];
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *)arSession.configuration;
    configuration.initialWorldMap = self.worldMap;
    [arSession runWithConfiguration:configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
    self.worldMap = nil;
    NSLog(@"[world_map] did load ARWorldMap");
}

- (void)setIsStereoscopicRendering:(BOOL)val {
    holokit::HoloKitApi::GetInstance()->SetStereoscopicRendering(val);
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    // ARWorldMap status
    if (self.scanEnvironment) {
        if (self.currentARWorldMappingStatus != frame.worldMappingStatus) {
            self.currentARWorldMappingStatus = frame.worldMappingStatus;
            if (ARWorldMappingStatusDidChangeDelegate) {
                ARWorldMappingStatusDidChangeDelegate((int)self.currentARWorldMappingStatus);
            }
        }
    }
    
    // Hand tracking
//    if ([[HandTracker sharedHandTracker] isHandTrackingOn]) {
//        [[HandTracker sharedHandTracker] performHumanHandPoseRequest:frame];
//    }
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
    }

    for (ARAnchor *anchor in anchors) {
        if ([anchor isKindOfClass:[ARParticipantAnchor class]]) {
            if (DidAddARParticipantAnchorDelegate) {
                DidAddARParticipantAnchorDelegate();
            }
            NSLog(@"[ar_session] did add an ARParticipantAnchor");
            continue;
        }
        if (anchor.name != nil) {
//            if (![self.multipeerSession isHost] && [anchor.name isEqualToString:@"origin"]) {
//                NSLog(@"[ar_session] did receive an origin anchor");
//                [session setWorldOrigin:anchor.transform];
//                continue;
//            }
        }
    }
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate) {
        [self.unityARSessionDelegate session:session didUpdateAnchors:anchors];
    }
}
    
- (void)session:(ARSession *)session didRemoveAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate) {
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
    if (self.unityARSessionDelegate) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    
//    if (self.multipeerSession != nil) {
//        if (self.multipeerSession.mcSession.connectedPeers.count > 0) {
//            if (data.priority == ARCollaborationDataPriorityCritical) {
//                NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:NO error:nil];
//                [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
//            } else {
//                // Stop sending optional data after synchronization phase.
//                if (!self.isSynchronizationComplete) {
//                    NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:NO error:nil];
//                    [self.multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataUnreliable];
//                }
//            }
//        }
//    }
}

#pragma mark - ARSessionObserver

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    switch (camera.trackingState) {
        case ARTrackingStateNotAvailable:
            NSLog(@"[ar_session] AR tracking state changed to not available");
            if (CameraDidChangeTrackingStateDelegate) {
                CameraDidChangeTrackingStateDelegate(0);
            }
            break;
        case ARTrackingStateLimited:
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: None");
                    if (CameraDidChangeTrackingStateDelegate != NULL) {
                        CameraDidChangeTrackingStateDelegate(1);
                    }
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Initializing");
                    if (CameraDidChangeTrackingStateDelegate != NULL) {
                        CameraDidChangeTrackingStateDelegate(2);
                    }
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Excessive motion");
                    if (CameraDidChangeTrackingStateDelegate != NULL) {
                        CameraDidChangeTrackingStateDelegate(3);
                    }
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Insufficient features");
                    if (CameraDidChangeTrackingStateDelegate != NULL) {
                        CameraDidChangeTrackingStateDelegate(4);
                    }
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Relocalizing");
                    if (CameraDidChangeTrackingStateDelegate != NULL) {
                        CameraDidChangeTrackingStateDelegate(5);
                    }
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ar_session] AR tracking state changed to normal");
            if (CameraDidChangeTrackingStateDelegate != NULL) {
                CameraDidChangeTrackingStateDelegate(6);
            }
            break;
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"[ar_session] session was interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"[ar_session] session interruption ended");
}

- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session {
    NSLog(@"[ar_session] sessionShouldAttemptRelocalization %d", self.sessionShouldAttemptRelocalization);
    return self.sessionShouldAttemptRelocalization;
}

@end

#pragma mark - extern "C"

extern "C" {

#pragma mark - AR Session

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    if (ar_native_session == nullptr) {
        NSLog(@"[ar_session]: native ARSession is NULL.");
        return;
    }
    
    ARSession* sessionPtr = (__bridge ARSession*)ar_native_session->sessionPtr;
    ARSessionDelegateController* arSessionDelegateController = [ARSessionDelegateController sharedARSessionDelegateController];
    arSessionDelegateController.unityARSessionDelegate = sessionPtr.delegate;
    [arSessionDelegateController setArSession:sessionPtr];
    
    [sessionPtr setDelegate:arSessionDelegateController];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    
    ARSessionDelegateController* ar_session = [ARSessionDelegateController sharedARSessionDelegateController];
    [ar_session.arSession setWorldOrigin:(transform_matrix)];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionDelegateController sharedARSessionDelegateController] setSessionShouldAttemptRelocalization:value];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(CameraDidChangeTrackingState callback) {
    CameraDidChangeTrackingStateDelegate = callback;
}

#pragma mark - iOS Thermal API

int UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_GetThermalState() {
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    return (int)thermalState;
}
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetThermalStateDidChangeDelegate(ThermalStateDidChange callback) {
    ThermalStateDidChangeDelegate = callback;
}

#pragma mark - ARWorldMap API

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetScanEnvironment(bool value) {
    [[ARSessionDelegateController sharedARSessionDelegateController] setScanEnvironment:value];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARWorldMappingStatusDidChangeDelegate(ARWorldMappingStatusDidChange callback) {
    ARWorldMappingStatusDidChangeDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SaveARWorldMap(const char *mapName) {
    [[ARSessionDelegateController sharedARSessionDelegateController] saveARWorldMap:[NSString stringWithUTF8String:mapName]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidSaveARWorldMapDelegate(DidSaveARWorldMap callback) {
    DidSaveARWorldMapDelegate = callback;
}

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_RetrieveARWorldMap(const char *mapName) {
    return [[ARSessionDelegateController sharedARSessionDelegateController] retrieveARWorldMap:[NSString stringWithUTF8String:mapName]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_LoadARWorldMap() {
    [[ARSessionDelegateController sharedARSessionDelegateController] loadARWorldMap];
}

} // extern "C"
