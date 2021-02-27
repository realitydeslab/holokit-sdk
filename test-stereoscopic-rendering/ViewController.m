//
//  ViewController.m
//  HoloKitStereoscopicRendering
//
//  Created by Yuchen on 2021/2/4.
//

#import "ViewController.h"
#import "Renderer.h"
#import "MathHelper.h"


#define MIN(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#define MAX(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })

#define CLAMP(x, low, high) ({\
  __typeof__(x) __x = (x); \
  __typeof__(low) __low = (low);\
  __typeof__(high) __high = (high);\
  __x > __high ? __high : (__x < __low ? __low : __x);\
  })

@interface ViewController () <MTKViewDelegate, ARSessionDelegate, TrackerDelegate>

@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) Renderer *renderer;
// for handtracking
@property (nonatomic, strong) HandTracker *handTracker;
@property (nonatomic, strong) NSArray<NSArray<Landmark *> *> *landmarks;
// for handtracking debug
@property (assign) double landmarkZMin;
@property (assign) double landmarkZMax;
// for apple hand detection
//@property (nonatomic, strong) AVCaptureSession *cameraFeedSession;
@property (nonatomic, strong) VNDetectHumanHandPoseRequest *handPoseRequest;

@end


@interface MTKView () <RenderDestinationProvider>

@end


@implementation ViewController {
    
    // for depth data
    CVMetalTextureRef _depthTextureRef;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create an ARSession
    self.session = [ARSession new];
    self.session.delegate = self;
    
    // Set hand tracker
    _landmarkZMin = 1000;
    _landmarkZMax = -1000;
    self.handTracker = [[HandTracker alloc] init];
    self.handTracker.delegate = self;
    [self.handTracker startGraph];
    
    // apple hand detection
    //self.handPoseRequest = [[VNDetectHumanHandPoseRequest alloc] init];
    //self.handPoseRequest.maximumHandCount = 1;
    
    // Set the view to use the default device
    MTKView *view = (MTKView *)self.view;
    view.device = MTLCreateSystemDefaultDevice();
    view.backgroundColor = UIColor.clearColor;
    view.delegate = self;
    
    if(!view.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    
    // Configure the renderer to draw to the view
    self.renderer = [[Renderer alloc] initWithSession:self.session metalDevice:view.device renderDestinationProvider:view];
    
    [self.renderer drawRectResized:view.bounds.size drawableSize:view.drawableSize];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    NSMutableArray *gestureRecognizers = [NSMutableArray array];
    [gestureRecognizers addObject:tapGesture];
    [gestureRecognizers addObjectsFromArray:view.gestureRecognizers];
    view.gestureRecognizers = gestureRecognizers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
    // for scene depth
    //configuration.frameSemantics = ARFrameSemanticSmoothedSceneDepth;
    configuration.frameSemantics = ARFrameSemanticSceneDepth;

    [self.session runWithConfiguration:configuration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.session pause];
}

- (void)handleTap:(UIGestureRecognizer*)gestureRecognize {
    ARFrame *currentFrame = [self.session currentFrame];
    
    // Create anchor using the camera's current position
    if (currentFrame) {
        
        // Create a transform with a translation of 0.2 meters in front of the camera
        matrix_float4x4 translation = matrix_identity_float4x4;
        // TODO: place the geometry on a physical plane
        translation.columns[3].z = -0.2;
        matrix_float4x4 transform = matrix_multiply(currentFrame.camera.transform, translation);
        
        // Add a new anchor to the session
        ARAnchor *anchor = [[ARAnchor alloc] initWithTransform:transform];
        [self.session addAnchor:anchor];
    }
}

#pragma mark - MTKViewDelegate

// Called whenever view changes orientation or layout is changed
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self.renderer drawRectResized:view.bounds.size drawableSize:size];
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
    [self.renderer update];
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    // process capturedImage for handtracking
    
    //NSLog(@"handTracker.processVideoFrame is called");
    [self.handTracker processVideoFrame: frame.capturedImage];
    return;
    
    
    // for apple hand detection
    NSLog(@"Apple Vision Hand Detection is running");
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer: frame.capturedImage orientation:kCGImagePropertyOrientationUp options:[NSMutableDictionary dictionary]];
    @try {
        // perform hand detection algorithm
        NSArray<VNRequest *> * requests = [[NSArray alloc] initWithObjects:_handPoseRequest, nil];
        [handler performRequests:requests error:nil];
        // TODO: check if hand detection is run in this frame
        
        VNHumanHandPoseObservation *observation = _handPoseRequest.results.firstObject;
        if(observation == nil) {
            //NSLog(@"observation is nil...");
            return;
        }
        
        // an array of all landmarks
        NSDictionary<VNRecognizedPointKey, VNRecognizedPoint*>* landmarks = [observation recognizedPointsForGroupKey:VNRecognizedPointGroupKeyAll error:nil];
        
        ARDepthData* sceneDepth = _session.currentFrame.sceneDepth;
        if (!sceneDepth){
            NSLog(@"ViewController");
            NSLog(@"Failed to acquire scene depth.");
            return;
        }
        CVPixelBufferRef pixelBuffer = sceneDepth.depthMap;
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
        Float32* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        // remove all handtracking anchors from last frame
        for(ARAnchor *anchor in frame.anchors){
            if([anchor.name isEqual:@"handtracking"]) {
                [_session removeAnchor:anchor];
            }
        }
    
        //NSLog(@"dictionary size: %d", landmarks.count);
        for(id key in landmarks) {
            VNRecognizedPoint *landmark = [landmarks objectForKey:key];
            int x = (CGFloat)landmark.location.x * frame.camera.imageResolution.width;
            int y = (CGFloat)(1 - landmark.location.y) * frame.camera.imageResolution.height;
            CGPoint screenPoint = CGPointMake(x, y);
            //NSLog(@"[%f, f%]", landmark.location.x, landmark.location.y);
            
            int depthX = landmark.x * bufferWidth;
            int depthY = (1 - landmark.y) * bufferHeight;
            float landmarkDepth = baseAddress[depthY * bufferWidth + depthX];
            
            simd_float4x4 anchorTransform = [self unprojectScreenPointToTransform:screenPoint depth:landmarkDepth currentFrame:frame];
            ARAnchor *anchor = [[ARAnchor alloc] initWithName:@"handtracking" transform:anchorTransform];
            [_session addAnchor:anchor];
             
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
    } @catch(NSException * e) {
        NSLog(@"Apple hand detection not working...");
    }
    
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Present an error message to the user
    
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
}

#pragma mark - HandTracking

- (simd_float4x4)unprojectScreenPointToTransform:(CGPoint)screenPoint depth:(float)z currentFrame:(ARFrame *) frame{
    simd_float4x4 translation = matrix_identity_float4x4;
    translation.columns[3].z = -z;
    simd_float4x4 planeOrigin = simd_mul(frame.camera.transform, translation);
    simd_float3 xAxis = simd_make_float3(1, 0, 0);
    simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
    simd_float4x4 plane = simd_mul(planeOrigin, rotation);
    simd_float3 unprojectedPoint = [frame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:frame.camera.imageResolution];
    simd_float4x4 transform = matrix_identity_float4x4;
    transform.columns[3].x = unprojectedPoint.x;
    transform.columns[3].y = unprojectedPoint.y;
    transform.columns[3].z = unprojectedPoint.z;
    
    return transform;
}


- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    NSLog(@"MediaPipe hand tracking is running");
    self.landmarks = multiLandmarks;
    
    if(self.session.currentFrame == nil){
        return;
    }
    ARFrame *currentFrame = _session.currentFrame;
    // remove all handtracking anchors from last frame
    for(ARAnchor *anchor in currentFrame.anchors){
        if([anchor.name isEqual:@"handtracking"]) {
            [self.session removeAnchor:anchor];
        }
    }
    
    // get the scene depth
    //ARDepthData* sceneDepth = _session.currentFrame.smoothedSceneDepth;
    ARDepthData* sceneDepth = _session.currentFrame.sceneDepth;
    if (!sceneDepth){
        NSLog(@"ViewController");
        NSLog(@"Failed to acquire scene depth.");
        return;
    }
    CVPixelBufferRef pixelBuffer = sceneDepth.depthMap;
    
    // from https://stackoverflow.com/questions/34569750/get-pixel-value-from-cvpixelbufferref-in-swift
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    
    Float32* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    for(NSArray<Landmark *> *landmarks in multiLandmarks){
        for(Landmark *landmark in landmarks){
            
            //NSLog(@"idx: %d", landmarkIndex);
            int x = (CGFloat)landmark.x * currentFrame.camera.imageResolution.width;
            int y = (CGFloat)landmark.y * currentFrame.camera.imageResolution.height;
            CGPoint screenPoint = CGPointMake(x, y);
            
            // fetch the depth value of this landamrk
            int depthX = CLAMP(landmark.x, 0, 1) * bufferWidth;
            int depthY = CLAMP(landmark.y, 0, 1) * bufferHeight;
            float landmarkDepth = baseAddress[depthY * bufferWidth + depthX];

            simd_float4x4 finalTransform = [self unprojectScreenPointToTransform:screenPoint depth:landmarkDepth currentFrame:currentFrame];
            ARAnchor *anchor = [[ARAnchor alloc] initWithName:@"handtracking" transform:finalTransform];
            
            [self.session addAnchor:anchor];
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses {
    
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer {
    
}

#pragma mark - Apple Hand Detection


@end
