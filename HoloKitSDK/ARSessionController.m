#import <ARKit/ARKit.h>
#import "UnityPluginApi/XR/UnityXRNativePtrs.h"

void (*OnThermalStateChanged)(int) = NULL;
void (*OnCameraChangedTrackingState)(int) = NULL;
void (*OnARWorldMapStatusChanged)(int) = NULL;
void (*OnGotCurrentARWorldMap)(void) = NULL;
void (*OnCurrentARWorldMapSaved)(const char *, float) = NULL;
void (*OnGotARWorldMapFromDisk)(const char *, unsigned char *, int) = NULL;
void (*OnARWorldMapLoaded)(void) = NULL;
void (*OnRelocalizationSucceeded)(void) = NULL;

@interface ARSessionController : NSObject

@end

@interface ARSessionController() <ARSessionDelegate>

@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) ARSession* session;
@property (nonatomic, strong, nullable) ARWorldMap *worldMap;
@property (assign) BOOL scaningEnvironment;
@property (assign) ARWorldMappingStatus currentARWorldMappingStatus;
@property (assign) BOOL sessionShouldAttemptRelocalization;
@property (assign) BOOL isRelocalizing;

@end

@implementation ARSessionController

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        self.scaningEnvironment = NO;
        self.currentARWorldMappingStatus = ARWorldMappingStatusNotAvailable;
        self.sessionShouldAttemptRelocalization = false;
        self.isRelocalizing = false;
        
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

- (void)pauseCurrentARSession {
    if (self.session != nil) {
        [self.session pause];
    }
}

- (void)resumeCurrentARSession {
    if (self.session != nil) {
        [self.session runWithConfiguration:self.session.configuration];
    }
}

- (void)getCurentARWorldMap {
    if (self.currentARWorldMappingStatus != ARWorldMappingStatusMapped) {
        NSLog(@"[ARWorldMap] Current ARWorldMap is not available");
        return;
    }
    [self.session getCurrentWorldMapWithCompletionHandler:^(ARWorldMap * _Nullable worldMap, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[ARWorldMap] Failed to get current ARWorldMap");
            return;
        }
        self.worldMap = worldMap;
        if (OnGotCurrentARWorldMap != NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                OnGotCurrentARWorldMap();
            });
        }
    }];
}

- (void)saveCurrentARWorldMapWithName:(NSString *)mapName {
    if (self.worldMap == nil) {
        NSLog(@"[ARSession] There is no current ARWorldMap");
        return;
    }
    
    NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:self.worldMap requiringSecureCoding:NO error:nil];
    // Create map folder if necessary
    NSString *directoryPath = [NSString stringWithFormat:@"%@%@", NSHomeDirectory(), @"/Documents/ARWorldMaps/"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // Generate map file path
    NSString *filePath = [NSString stringWithFormat:@"%@%@%@", directoryPath, mapName, @".arexperience"];
    // Save map data to the path
    [mapData writeToFile:filePath atomically:YES];
    
    float mapSizeInMegabytes = mapData.length / (1024.0 * 1024.0);
    if (OnCurrentARWorldMapSaved != NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OnCurrentARWorldMapSaved([mapName UTF8String], mapSizeInMegabytes);
        });
    }
}

- (void)getARWorldMapFromDiskWithName:(NSString *)mapName {
    NSString *filePath = [NSString stringWithFormat:@"%@%@%@%@", NSHomeDirectory(), @"/Documents/ARWorldMaps/", mapName, @".arexperience"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *mapData = [[NSData alloc] initWithContentsOfFile:filePath];
        self.worldMap = nil;
        self.worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:mapData error:nil];
        if (self.worldMap == nil) {
            NSLog(@"[ARSessionController] Failed to get ARWorldMap from path: %@", filePath);
            return;
        }
        NSLog(@"[ARSessionController] Got ARWorldMap %@ from disk with size %lu bytes", mapName, mapData.length);
        // Marshal map data back to C#
        unsigned char *data = (unsigned char *)[mapData bytes];
        if (OnGotARWorldMapFromDisk != NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                OnGotARWorldMapFromDisk([mapName UTF8String], data, (int)mapData.length);
            });
        }
    } else {
        NSLog(@"[ARSessionController] Failed to get ARWorldMap from path: %@", filePath);
    }
}

- (void)loadARWorldMapWithData:(NSData *)mapData {
    self.worldMap = nil;
    self.worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:mapData error:nil];
    if (self.worldMap == nil) {
        NSLog(@"[ARSessionController] Load ARWorldMap with invalid map data");
        return;
    }
    if (OnARWorldMapLoaded != NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OnARWorldMapLoaded();
        });
    }
}

- (void)relocalizeToLoadedARWorldMap {
    if (self.worldMap == nil) {
        NSLog(@"[ARSessionController] There is no ARWorldMap to relocalize");
        return;
    }
    if (self.session == nil) {
        NSLog(@"[ARSessionController] There is no ARSession available");
        return;
    }
    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *)self.session.configuration;
    configuration.initialWorldMap = self.worldMap;
    [self.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
    self.isRelocalizing = true;
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }

    // ARWorldMap status
    if (self.scaningEnvironment) {
        if (self.currentARWorldMappingStatus != frame.worldMappingStatus) {
            switch (self.currentARWorldMappingStatus) {
                case ARWorldMappingStatusNotAvailable:
                    NSLog(@"[ARSessionController] Current ARWorldMapStatus changed to not available");
                    break;
                case ARWorldMappingStatusLimited:
                    NSLog(@"[ARSessionController] Current ARWorldMapStatus changed to limited");
                    break;
                case ARWorldMappingStatusExtending:
                    NSLog(@"[ARSessionController] Current ARWorldMapStatus changed to extending");
                    break;
                case ARWorldMappingStatusMapped:
                    NSLog(@"[ARSessionController] Current ARWorldMapStatus changed to mapped");
                    break;
            }
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
            NSLog(@"[ARSessionObserver] Camera tracking state changed to not available");
            if (OnCameraChangedTrackingState != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnCameraChangedTrackingState(0);
                });
            }
            break;
        case ARTrackingStateLimited:
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    NSLog(@"[ARSessionObserver] Camera tracking state changed to limited, with reason: None");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(1);
                        });
                    }
                    break;
                case ARTrackingStateReasonInitializing:
                    NSLog(@"[ARSessionObserver] Camera tracking state changed to limited, with reason: Initializing");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(2);
                        });
                    }
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    NSLog(@"[ARSessionObserver] Camera tracking state changed to limited, with reason: Excessive motion");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(3);
                        });
                    }
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    NSLog(@"[ARSessionObserver] Camera tracking state changed to limited, with reason: Insufficient features");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(4);
                        });
                    }
                    break;
                case ARTrackingStateReasonRelocalizing:
                    NSLog(@"[ARSessionObserver] Camera tracking state changed to limited, with reason: Relocalizing");
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(5);
                        });
                    }
                    break;
            }
            break;
        case ARTrackingStateNormal:
            NSLog(@"[ARSessionObserver] Camera tracking state changed to normal");
            if (OnCameraChangedTrackingState != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnCameraChangedTrackingState(6);
                });
            }
            if (self.isRelocalizing) {
                if (OnRelocalizationSucceeded != NULL) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        OnRelocalizationSucceeded();
                    });
                }
                self.isRelocalizing = false;
            }
            break;
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"[ARSessionObserver] Session was interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"[ARSessionObserver] Session interruption ended");
}

- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session {
    NSLog(@"[ARSessionObserver] SessionShouldAttemptRelocalization %d", self.sessionShouldAttemptRelocalization);
    return self.sessionShouldAttemptRelocalization;
}

@end

void HoloKitSDK_InterceptUnityARSessionDelegate(UnityXRNativeSession* nativeARSessionPtr) {
    if (nativeARSessionPtr == NULL) {
        NSLog(@"[HoloKitSDK] Native ARSession is NULL");
        return;
    }
    ARSession* sessionPtr = (__bridge ARSession*)nativeARSessionPtr->sessionPtr;
    ARSessionController* arSessionDelegateController = [ARSessionController sharedInstance];
    arSessionDelegateController.unityARSessionDelegate = sessionPtr.delegate;
    [arSessionDelegateController setSession:sessionPtr];
    [sessionPtr setDelegate:arSessionDelegateController];
}

int HoloKitSDK_GetThermalState(void) {
    NSProcessInfoThermalState thermalState = [[NSProcessInfo processInfo] thermalState];
    return (int)thermalState;
}

void HoloKitSDK_PauseCurrentARSession(void) {
    [[ARSessionController sharedInstance] pauseCurrentARSession];
}

void HoloKitSDK_ResumeCurrentARSession(void) {
    [[ARSessionController sharedInstance] resumeCurrentARSession];
}

void HoloKitSDK_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionController sharedInstance] setSessionShouldAttemptRelocalization:value];
}

void HoloKitSDK_SetScaningEnvironment(bool value) {
    [[ARSessionController sharedInstance] setScaningEnvironment:value];
}

void HoloKitSDK_GetCurrentARWorldMap(void) {
    [[ARSessionController sharedInstance] getCurentARWorldMap];
}

void HoloKitSDK_SaveCurrentARWorldMapWithName(const char *mapName) {
    [[ARSessionController sharedInstance] saveCurrentARWorldMapWithName:[NSString stringWithUTF8String:mapName]];
}

void HoloKitSDK_GetARWorldMapFromDiskWithName(const char *mapName) {
    [[ARSessionController sharedInstance] getARWorldMapFromDiskWithName:[NSString stringWithUTF8String:mapName]];
}

void HoloKitSDK_LoadARWorldMapWithData(unsigned char *mapData, int dataSizeInBytes) {
    NSData *nsMapData = [NSData dataWithBytes:mapData length:dataSizeInBytes];
    [[ARSessionController sharedInstance] loadARWorldMapWithData:nsMapData];
}

void HoloKitSDK_RelocalizeToLoadedARWorldMap(void) {
    [[ARSessionController sharedInstance] relocalizeToLoadedARWorldMap];
}

void HoloKitSDK_RegisterARSessionControllerDelegates(void (*OnThermalStateChangedDelegate)(int),
                                                     void (*OnCameraChangedTrackingStateDelegate)(int),
                                                     void (*OnARWorldMapStatusChangedDelegate)(int),
                                                     void (*OnGotCurrentARWorldMapDelegate)(void),
                                                     void (*OnCurrentARWorldMapSavedDelegate)(const char *, float),
                                                     void (*OnGotARWorldMapFromDiskDelegate)(const char *, unsigned char *, int),
                                                     void (*OnARWorldMapLoadedDelegate)(void),
                                                     void (*OnRelocalizationSucceededDelegate)(void)) {
    OnThermalStateChanged = OnThermalStateChangedDelegate;
    OnCameraChangedTrackingState = OnCameraChangedTrackingStateDelegate;
    OnARWorldMapStatusChanged = OnARWorldMapStatusChangedDelegate;
    OnGotCurrentARWorldMap = OnGotCurrentARWorldMapDelegate;
    OnCurrentARWorldMapSaved = OnCurrentARWorldMapSavedDelegate;
    OnGotARWorldMapFromDisk = OnGotARWorldMapFromDiskDelegate;
    OnARWorldMapLoaded = OnARWorldMapLoadedDelegate;
    OnRelocalizationSucceeded = OnRelocalizationSucceededDelegate;
}
