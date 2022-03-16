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

- (void)saveARWorldMap {
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
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
        NSString *mapName = [dateFormatter stringFromDate:[NSDate date]];
        
        NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:worldMap requiringSecureCoding:NO error:nil];
        NSURL *url = [[[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil]
                      URLByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", mapName, @".arexperience"]];
        
        [mapData writeToURL:url atomically:true];
        NSLog(@"[world_map] saved ARWorldMap in %f", [[NSProcessInfo processInfo] systemUptime] - startTime);
        NSLog(@"[world_map] map name: %@\nmap size: %f\nmap path %@", mapName, mapData.length / (1024.0 * 1024.0), url);
        if (DidSaveARWorldMapDelegate != NULL) {
            DidSaveARWorldMapDelegate([mapName UTF8String]);
        }
    }];
}

- (int)searchARWorldMaps {
    NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSUInteger length = [url.absoluteString length];
    
    __block int numOfMaps = 0;
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSURL *fileUrl = (NSURL *)obj;
        NSString *fileStr = fileUrl.absoluteString;
        NSString *extension = [[fileStr pathExtension] lowercaseString];
        if ([extension isEqualToString:@"arexperience"]) {
            NSString *mapName = [fileStr substringFromIndex:length + 8]; // private/
            mapName = [mapName substringToIndex:mapName.length - 13]; // .arexperience
            mapName = [mapName stringByReplacingOccurrencesOfString:@"%20" withString:@" "]; // %20
            NSLog(@"[world_map] found map %@", mapName);
            if (DidFindARWorldMapDelegate != NULL) {
                DidFindARWorldMapDelegate([mapName UTF8String]);
            }
            numOfMaps++;
        }
    }];
    return numOfMaps;
}

- (void)retrieveARWorldMap:(NSString *)mapName {
    NSLog(@"[loadARWorldMap] mapName %@", mapName);
    NSURL *url = [[[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil]
                  URLByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", mapName, @".arexperience"]];
    NSData *mapData = [[NSData alloc] initWithContentsOfURL:url];
    ARWorldMap *worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:mapData error:nil];
    if (worldMap == nil) {
        NSLog(@"[world_map] failed to decode saved ARWorldMap, URL: %@", url);
        return;
    }
    NSLog(@"[world_map] did retrieve ARWorldMap of size %f mb from path %@", mapData.length / (1024.0 * 1024.0), url);
    self.worldMap = worldMap;
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
    holokit::HoloKitApi::GetInstance()->SetIsStereoscopicRendering(val);
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
            if (DidAddARParticipantAnchorDelegate != NULL) {
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
            if (CameraDidChangeTrackingStateDelegate != NULL) {
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

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSession(UnityXRNativeSession* ar_native_session) {
    if (ar_native_session == nullptr) {
        NSLog(@"[ar_session]: native ARSession is NULL.");
        return;
    }
    
    ARSession* sessionPtr = (__bridge ARSession*)ar_native_session->sessionPtr;
    ARSessionDelegateController* ar_session_manager = [ARSessionDelegateController sharedARSessionDelegateController];
    ar_session_manager.unityARSessionDelegate = sessionPtr.delegate;
    
    [sessionPtr setDelegate:ar_session_manager];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetWorldOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
    
    ARSessionDelegateController* ar_session = [ARSessionDelegateController sharedARSessionDelegateController];
    [ar_session.arSession setWorldOrigin:(transform_matrix)];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_AddNativeAnchor(const char * anchorName, float position[3], float rotation[4]) {
//    ARSessionDelegateController *session = [ARSessionDelegateController sharedARSessionDelegateController];
//    simd_float4x4 transform_matrix = UnityPositionAndRotation2SimdFloat4x4(position, rotation);
//    std::vector<float> rot = SimdFloat4x42UnityRotation(transform_matrix);
//    NSString *name = [NSString stringWithUTF8String:anchorName];
//    if ([name isEqualToString:@"origin"]){
//        // Do not accumulate anchors.
//        if (session.originAnchor != nil) {
//            [session.arSession removeAnchor:session.originAnchor];
//        }
//        session.originAnchor = [[ARAnchor alloc] initWithName:name transform:transform_matrix];
//        [session.arSession addAnchor:session.originAnchor];
//    } else {
//        ARAnchor* anchor = [[ARAnchor alloc] initWithName:name transform:transform_matrix];
//        [session.arSession addAnchor:anchor];
//    }
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

#pragma mark - CameraTrackingState API

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetCameraDidChangeTrackingStateDelegate(CameraDidChangeTrackingState callback) {
    CameraDidChangeTrackingStateDelegate = callback;
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
UnityHoloKit_SaveARWorldMap() {
    [[ARSessionDelegateController sharedARSessionDelegateController] saveARWorldMap];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidSaveARWorldMapDelegate(DidSaveARWorldMap callback) {
    DidSaveARWorldMapDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_RetrieveARWorldMap(const char *mapName) {
    [[ARSessionDelegateController sharedARSessionDelegateController] retrieveARWorldMap:[NSString stringWithUTF8String:mapName]];
}

int UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SearchARWorldMaps() {
    int numOfMaps = [[ARSessionDelegateController sharedARSessionDelegateController] searchARWorldMaps];
    NSLog(@"[world_map] found %d maps in total", numOfMaps);
    return numOfMaps;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidFindARWorldMapDelegate(DidFindARWorldMap callback) {
    DidFindARWorldMapDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_LoadARWorldMap() {
    [[ARSessionDelegateController sharedARSessionDelegateController] loadARWorldMap];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionDelegateController sharedARSessionDelegateController] setSessionShouldAttemptRelocalization:value];
}

} // extern "C"
