#import <ARKit/ARKit.h>
#import "UnityPluginApi/XR/UnityXRNativePtrs.h"

void (*OnThermalStateChanged)(int) = NULL;
void (*OnCameraChangedTrackingState)(int) = NULL;
void (*OnARWorldMapStatusChanged)(int) = NULL;
void (*OnGotARWorldMap)(void) = NULL;

@interface ARSessionController : NSObject

@end

@interface ARSessionController() <ARSessionDelegate>

@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) ARSession* session;
@property (nonatomic, strong, nullable) ARWorldMap *worldMap;
@property (assign) BOOL scaningEnvironment;
@property (assign) ARWorldMappingStatus currentARWorldMappingStatus;
@property (assign) BOOL sessionShouldAttemptRelocalization;

@end

@implementation ARSessionController

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        self.scaningEnvironment = NO;
        self.currentARWorldMappingStatus = ARWorldMappingStatusNotAvailable;
        self.sessionShouldAttemptRelocalization = false;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OnThermalStateChanged) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
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

- (void)OnThermalStateChanged {
    if (OnThermalStateChanged != NULL) {
        NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
        dispatch_async(dispatch_get_main_queue(), ^{
            OnThermalStateChanged((int)thermalState);
        });
    }
}

- (void)getCurentARWorldMap {
    if (self.currentARWorldMappingStatus != ARWorldMappingStatusMapped) {
        NSLog(@"[ARWorldMap] current ARWorldMap is not available");
        return;
    }
    [self.session getCurrentWorldMapWithCompletionHandler:^(ARWorldMap * _Nullable worldMap, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[ARWorldMap] failed to get current ARWorldMap");
            return;
        }
        self.worldMap = worldMap;
        if (OnGotARWorldMap != NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                OnGotARWorldMap();
            });
        }
    }];
}

- (void)saveCurrentARWorldMapWithName:(NSString *)mapName {
    // Serialize map data
//    NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:worldMap requiringSecureCoding:NO error:nil];
//    // Create map folder if necessary
//    NSString *directoryPath = [NSString stringWithFormat:@"%@%@", NSHomeDirectory(), @"/Documents/Maps/"];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath]) {
//        NSLog(@"[File] create directory %@", directoryPath);
//        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//    // Generate map file path
//    NSString *filePath = [NSString stringWithFormat:@"%@%@%@", directoryPath, mapName, @".arexperience"];
//    // Save map data to the path
//    [mapData writeToFile:filePath atomically:YES];
//    NSLog(@"[world_map] map name: %@\nmap size: %f mb\nmap path: %@", mapName, mapData.length / (1024.0 * 1024.0), filePath);
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
    
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *)self.session.configuration;
    configuration.initialWorldMap = self.worldMap;
    [self.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
    //self.worldMap = nil;
    NSLog(@"[world_map] did load ARWorldMap");
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }

    // ARWorldMap status
    if (self.scaningEnvironment) {
        if (self.currentARWorldMappingStatus != frame.worldMappingStatus) {
            self.currentARWorldMappingStatus = frame.worldMappingStatus;
            if (OnARWorldMapStatusChanged != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnARWorldMapStatusChanged((int)self.currentARWorldMappingStatus);
                });
            }
        }
    }
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor*>*)anchors {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didAddAnchors:anchors];
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
}

#pragma mark - ARSessionObserver

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera {
    switch (camera.trackingState) {
        case ARTrackingStateNotAvailable:
            NSLog(@"[ARSessionObserver] camera tracking state changed to not available");
            if (OnCameraChangedTrackingState != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnCameraChangedTrackingState(0);
                });
            }
            break;
        case ARTrackingStateLimited:
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ARSessionObserver] camera tracking state changed to limited, with reason: None");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(1);
                        });
                    }
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ARSessionObserver] camera tracking state changed to limited, with reason: Initializing");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(2);
                        });
                    }
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ARSessionObserver] camera tracking state changed to limited, with reason: Excessive motion");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(3);
                        });
                    }
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ARSessionObserver] camera tracking state changed to limited, with reason: Insufficient features");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(4);
                        });
                    }
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ARSessionObserver] camera tracking state changed to limited, with reason: Relocalizing");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(5);
                        });
                    }
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ARSessionObserver] camera tracking state changed to normal");
            if (OnCameraChangedTrackingState != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnCameraChangedTrackingState(6);
                });
            }
            break;
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"[ARSessionObserver] session was interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"[ARSessionObserver] session interruption ended");
}

- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session {
    NSLog(@"[ARSessionObserver] sessionShouldAttemptRelocalization %d", self.sessionShouldAttemptRelocalization);
    return self.sessionShouldAttemptRelocalization;
}

@end

#pragma mark - AR Session

void HoloKitSDK_InterceptUnityARSessionDelegate(UnityXRNativeSession* nativeARSessionPtr) {
    if (nativeARSessionPtr == nil) {
        NSLog(@"[HoloKitSDK]: native ARSession is NULL");
        return;
    }
    ARSession* sessionPtr = (__bridge ARSession*)nativeARSessionPtr->sessionPtr;
    ARSessionController* arSessionDelegateController = [ARSessionController sharedInstance];
    arSessionDelegateController.unityARSessionDelegate = sessionPtr.delegate;
    [arSessionDelegateController setSession:sessionPtr];
    [sessionPtr setDelegate:arSessionDelegateController];
}

void HoloKitSDK_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionController sharedInstance] setSessionShouldAttemptRelocalization:value];
}

int HoloKitSDK_GetThermalState(void) {
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    return (int)thermalState;
}

void HoloKitSDK_SetScaningEnvironment(bool value) {
    [[ARSessionController sharedInstance] setScaningEnvironment:value];
}

void HoloKitSDK_GetCurrentARWorldMap(void) {
    [[ARSessionController sharedInstance] getCurentARWorldMap];
}

//bool UnityHoloKit_RetrieveARWorldMap(const char *mapName) {
//    return [[ARSessionController sharedInstance] retrieveARWorldMap:[NSString stringWithUTF8String:mapName]];
//}
//
//void nityHoloKit_LoadARWorldMap() {
//    [[ARSessionController sharedInstance] loadARWorldMap];
//}
