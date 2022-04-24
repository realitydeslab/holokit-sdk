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
#import "multipeer_session.h"

// For testing purpose
//#import <os/log.h>
//#import <os/signpost.h>

typedef void (*ThermalStateDidChange)(int state);
ThermalStateDidChange ThermalStateDidChangeDelegate = NULL;

typedef void (*CameraDidChangeTrackingState)(int trackingState);
CameraDidChangeTrackingState CameraDidChangeTrackingStateDelegate = NULL;

typedef void (*ARWorldMappingStatusDidChange)(int status);
ARWorldMappingStatusDidChange ARWorldMappingStatusDidChangeDelegate = NULL;

typedef void (*DidSaveARWorldMap)(const char *mapName);
DidSaveARWorldMap DidSaveARWorldMapDelegate = NULL;

typedef void (*DidAddNativeAnchor)(const char *anchorName, float *position, float *rotation);
DidAddNativeAnchor DidAddNativeAnchorDelegate = NULL;

@interface ARSessionDelegateController() <ARSessionDelegate>

@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (assign) BOOL scanEnvironment;

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

+ (id)sharedInstance {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)thermalStateDidChange {
    if (ThermalStateDidChangeDelegate) {
        NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
        ThermalStateDidChangeDelegate((int)thermalState);
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
            dispatch_async(dispatch_get_main_queue(), ^{
                DidSaveARWorldMapDelegate([mapName UTF8String]);
            });
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
        NSLog(@"[world_map] there is no ARWorldMap to load");
        return;
    }
    
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *)self.arSession.configuration;
    configuration.initialWorldMap = self.worldMap;
    [self.arSession runWithConfiguration:configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
    //self.worldMap = nil;
    NSLog(@"[world_map] did load ARWorldMap");
}

- (void)updateWithCollaborationData:(ARCollaborationData *_Nonnull) collaborationData {
    [self.arSession updateWithCollaborationData:collaborationData];
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
    
    if (DidAddNativeAnchorDelegate) {
        for (int i = 0; i < anchors.count; i++) {
            if (anchors[i].name || [anchors[i] isKindOfClass:[ARParticipantAnchor class]]) {
                std::vector<float> p = SimdFloat4x42UnityPosition(anchors[i].transform);
                std::vector<float> r = SimdFloat4x42UnityRotation(anchors[i].transform);
                dispatch_async(dispatch_get_main_queue(), ^{
                    float position[] = { p[0], p[1], p[2] };
                    float rotation[] = { r[0], r[1], r[2], r[3] };
                    DidAddNativeAnchorDelegate(anchors[i].name ? [anchors[i].name UTF8String] : [@"ARParticipantAnchor" UTF8String], position, rotation);
                });
            }
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
}

- (void)session:(ARSession *)session didOutputCollaborationData:(ARCollaborationData *)data {
    if (self.unityARSessionDelegate) {
        [self.unityARSessionDelegate session:session didOutputCollaborationData:data];
    }
    
    MultipeerSession *multipeerSession = [MultipeerSession sharedInstance];
    if (multipeerSession.mcSession != nil) {
        if (multipeerSession.mcSession.connectedPeers.count > 0) {
            NSData* encodedData = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:NO error:nil];
            // TODO: Send some data unreliably or just stopping sending them
            [multipeerSession sendToAllPeers:encodedData sendDataMode:MCSessionSendDataReliable];
        }
    }
}

#pragma mark - ARSessionObserver

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    switch (camera.trackingState) {
        case ARTrackingStateNotAvailable:
            NSLog(@"[ar_session] AR tracking state changed to not available");
            if (CameraDidChangeTrackingStateDelegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    CameraDidChangeTrackingStateDelegate(0);
                });
            }
            break;
        case ARTrackingStateLimited:
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: None");
                    if (CameraDidChangeTrackingStateDelegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CameraDidChangeTrackingStateDelegate(1);
                        });
                    }
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Initializing");
                    if (CameraDidChangeTrackingStateDelegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CameraDidChangeTrackingStateDelegate(2);
                        });
                    }
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Excessive motion");
                    if (CameraDidChangeTrackingStateDelegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CameraDidChangeTrackingStateDelegate(3);
                        });
                    }
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Insufficient features");
                    if (CameraDidChangeTrackingStateDelegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CameraDidChangeTrackingStateDelegate(4);
                        });
                    }
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ar_session] AR tracking state changed to limited, with reason: Relocalizing");
                    if (CameraDidChangeTrackingStateDelegate) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CameraDidChangeTrackingStateDelegate(5);
                        });
                    }
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ar_session] AR tracking state changed to normal");
            if (CameraDidChangeTrackingStateDelegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    CameraDidChangeTrackingStateDelegate(6);
                });
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
    ARSessionDelegateController* arSessionDelegateController = [ARSessionDelegateController sharedInstance];
    arSessionDelegateController.unityARSessionDelegate = sessionPtr.delegate;
    [arSessionDelegateController setArSession:sessionPtr];
    
    [sessionPtr setDelegate:arSessionDelegateController];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    
    ARSessionDelegateController* ar_session = [ARSessionDelegateController sharedInstance];
    [ar_session.arSession setWorldOrigin:(transform_matrix)];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionDelegateController sharedInstance] setSessionShouldAttemptRelocalization:value];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(CameraDidChangeTrackingState callback) {
    CameraDidChangeTrackingStateDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_AddNativeAnchor(const char * anchorName, float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    NSString *name = [NSString stringWithUTF8String:anchorName];
    ARAnchor* anchor = [[ARAnchor alloc] initWithName:name transform:transform_matrix];
    [[[ARSessionDelegateController sharedInstance] arSession] addAnchor:anchor];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidAddNativeAnchorDelegate(DidAddNativeAnchor callback) {
    DidAddNativeAnchorDelegate = callback;
}

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_IsARKitSupported() {
    return [ARConfiguration isSupported];
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
    [[ARSessionDelegateController sharedInstance] setScanEnvironment:value];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARWorldMappingStatusDidChangeDelegate(ARWorldMappingStatusDidChange callback) {
    ARWorldMappingStatusDidChangeDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SaveARWorldMap(const char *mapName) {
    [[ARSessionDelegateController sharedInstance] saveARWorldMap:[NSString stringWithUTF8String:mapName]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidSaveARWorldMapDelegate(DidSaveARWorldMap callback) {
    DidSaveARWorldMapDelegate = callback;
}

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_RetrieveARWorldMap(const char *mapName) {
    return [[ARSessionDelegateController sharedInstance] retrieveARWorldMap:[NSString stringWithUTF8String:mapName]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_LoadARWorldMap() {
    [[ARSessionDelegateController sharedInstance] loadARWorldMap];
}

} // extern "C"
