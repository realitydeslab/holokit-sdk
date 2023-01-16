#import <ARKit/ARKit.h>
#import "UnityPluginApi/XR/UnityXRNativePtrs.h"
#import "HandTracker.h"
#import "Utils.h"

void (*OnARSessionUpdatedFrame)(double, const float *);
void (*OnCameraChangedTrackingState)(int) = NULL;
void (*OnRelocalizationSucceeded)(void) = NULL;

typedef enum {
    BackgroundVideoFormat2K = 0,
    BackgroundVideoFormat4K = 1,
    BackgroundVideoFormat4KHDR = 2
} BackgroundVideoFormat;

@interface ARSessionDelegateManager : NSObject

@end

@interface ARSessionDelegateManager() <ARSessionDelegate>

@property (nonatomic, weak, nullable) id <ARSessionDelegate> unityARSessionDelegate;
@property (nonatomic, strong, nullable) ARSession *arSession;
@property (nonatomic, assign) BackgroundVideoFormat currentBackgroundVideoFormat;
@property (nonatomic, assign) BackgroundVideoFormat desiredBackgroundVideoFormat;
@property (assign) BOOL sessionShouldAttemptRelocalization;
@property (assign) BOOL isRelocalizing;

@end

@implementation ARSessionDelegateManager

#pragma mark - init
- (instancetype)init {
    if (self = [super init]) {
        self.currentBackgroundVideoFormat = BackgroundVideoFormat2K;
        self.desiredBackgroundVideoFormat = BackgroundVideoFormat2K;
        self.sessionShouldAttemptRelocalization = NO;
        self.isRelocalizing = NO;
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

- (void)pauseCurrentARSession {
    if (self.arSession != nil) {
        [self.arSession pause];
    }
}

- (void)resumeCurrentARSession {
    if (self.arSession != nil) {
        [self.arSession runWithConfiguration:self.arSession.configuration];
    }
}

- (void)checkBackgroundVideoFormat {
    if (@available(iOS 16, *)) {
        if (self.currentBackgroundVideoFormat == self.desiredBackgroundVideoFormat) {
            return;
        } else {
            self.currentBackgroundVideoFormat = self.desiredBackgroundVideoFormat;
        }
           
        ARWorldTrackingConfiguration *config = (ARWorldTrackingConfiguration *)self.arSession.configuration;
        if (ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution == nil) {
            NSLog(@"[HoloKitSDK] Current device does not support 4K video format");
            return;
        }
        
        if (self.currentBackgroundVideoFormat == BackgroundVideoFormat2K) {
            
            return;
        } else {
            config.videoFormat = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution;
            if (self.currentBackgroundVideoFormat == BackgroundVideoFormat4KHDR) {
                if (!config.videoFormat.videoHDRSupported) {
                    NSLog(@"[HoloKitSDK] Current device does not support HDR video format");
                    return;
                }
                config.videoHDRAllowed = true;
            }
        }
        [self.arSession runWithConfiguration:config];
    } else {
        NSLog(@"[HoloKitSDK] 4k video format is only supported on iOS 16.");
        return;
    }
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.unityARSessionDelegate != NULL) {
        [self.unityARSessionDelegate session:session didUpdateFrame:frame];
    }
    
    [self checkBackgroundVideoFormat];
    
    if (OnARSessionUpdatedFrame != NULL) {
        float *matrix = [Utils getUnityMatrix:frame.camera.transform];
        double timestamp = frame.timestamp;
        dispatch_async(dispatch_get_main_queue(), ^{
            OnARSessionUpdatedFrame(timestamp, matrix);
            delete[](matrix);
        });
    }
    
    // Hand tracking
    HandTracker *handTracker = [HandTracker sharedInstance];
    if ([handTracker active]) {
        [handTracker performHumanHandPoseRequest:frame];
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
            if (OnCameraChangedTrackingState != NULL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    OnCameraChangedTrackingState(0);
                });
            }
            break;
        case ARTrackingStateLimited:
            switch(camera.trackingStateReason) {
                case ARTrackingStateReasonNone:
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(1);
                        });
                    }
                    break;
                case ARTrackingStateReasonInitializing:
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(2);
                        });
                    }
                    break;
                case ARTrackingStateReasonExcessiveMotion:
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(3);
                        });
                    }
                    break;
                case ARTrackingStateReasonInsufficientFeatures:
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(4);
                        });
                    }
                    break;
                case ARTrackingStateReasonRelocalizing:
                    self.isRelocalizing = true;
                    if (OnCameraChangedTrackingState != NULL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            OnCameraChangedTrackingState(5);
                        });
                    }
                    break;
            }
            break;
        case ARTrackingStateNormal:
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

}

- (void)sessionInterruptionEnded:(ARSession *)session {

}

- (BOOL)sessionShouldAttemptRelocalization:(ARSession *)session {
    return self.sessionShouldAttemptRelocalization;
}

@end

extern "C" {

void HoloKitSDK_InterceptUnityARSessionDelegate(UnityXRNativeSession* nativeARSessionPtr) {
    if (nativeARSessionPtr == NULL) {
        NSLog(@"[HoloKitSDK] Native ARSession is NULL");
        return;
    }
    ARSession* sessionPtr = (__bridge ARSession*)nativeARSessionPtr->sessionPtr;
    ARSessionDelegateManager* arSessionDelegateManager = [ARSessionDelegateManager sharedInstance];
    arSessionDelegateManager.unityARSessionDelegate = sessionPtr.delegate;
    [arSessionDelegateManager setArSession:sessionPtr];
    [sessionPtr setDelegate:arSessionDelegateManager];
}

void HoloKitSDK_PauseCurrentARSession(void) {
    [[ARSessionDelegateManager sharedInstance] pauseCurrentARSession];
}

void HoloKitSDK_ResumeCurrentARSession(void) {
    [[ARSessionDelegateManager sharedInstance] resumeCurrentARSession];
}

void HoloKitSDK_SetSessionShouldAttemptRelocalization(bool value) {
    [[ARSessionDelegateManager sharedInstance] setSessionShouldAttemptRelocalization:value];
}

void HoloKitSDK_SetBackgroundVideoFormat(int format) {
    [[ARSessionDelegateManager sharedInstance] setDesiredBackgroundVideoFormat:(BackgroundVideoFormat)format];
}

void HoloKitSDK_RegisterARSessionControllerDelegates(void (*OnARSessionUpdatedFrameDelegate)(double, const float *),
                                                     void (*OnCameraChangedTrackingStateDelegate)(int),
                                                     void (*OnRelocalizationSucceededDelegate)(void)) {
    OnARSessionUpdatedFrame = OnARSessionUpdatedFrameDelegate;
    OnCameraChangedTrackingState = OnCameraChangedTrackingStateDelegate;
    OnRelocalizationSucceeded = OnRelocalizationSucceededDelegate;
}

void HoloKitSDK_ResetOrigin(float position[3], float rotation[4]) {
    simd_float4x4 transform_matrix = [Utils getSimdFloat4x4WithPosition:position rotation:rotation];
    [[[ARSessionDelegateManager sharedInstance] arSession] setWorldOrigin:transform_matrix];
}
 
}
