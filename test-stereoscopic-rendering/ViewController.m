//
//  ViewController.m
//  HoloKitStereoscopicRendering
//
//  Created by Yuchen on 2021/2/4.
//

#import "ViewController.h"
#import "Renderer.h"

@interface ViewController () <MTKViewDelegate, ARSessionDelegate, TrackerDelegate>

@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) Renderer *renderer;
// for handtracking
@property (nonatomic, strong) HandTracker *handTracker;
@property (nonatomic, strong) NSArray<NSArray<Landmark *> *> *landmarks;
// for handtracking debug
@property (assign) double landmarkZMin;
@property (assign) double landmarkZMax;

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
    configuration.frameSemantics = ARFrameSemanticSmoothedSceneDepth;

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
    [_handTracker processVideoFrame: frame.capturedImage];
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

- (void)handTracker:(HandTracker *)handTracker didOutputLandmarks:(NSArray<NSArray<Landmark *> *> *)multiLandmarks {
    
    //NSLog(@"handTracker function is called");
    _landmarks = multiLandmarks;
    
    if(_session.currentFrame == nil){
        return;
    }
    ARFrame *currentFrame = _session.currentFrame;
    // remove all handtracking anchors from last frame
    for(ARAnchor *anchor in currentFrame.anchors){
        if([anchor.name isEqual:@"handtracking"]) {
            [_session removeAnchor:anchor];
        }
    }
    
    for(NSArray<Landmark *> *landmarks in multiLandmarks){
        int idx = 0;
        for(Landmark *landmark in landmarks){
            
            int x = (CGFloat)landmark.x * currentFrame.camera.imageResolution.width;
            int y = (CGFloat)landmark.y * currentFrame.camera.imageResolution.height;
            //int x = (CGFloat)landmark.x * 1160.729858;
            //int y = (CGFloat)landmark.y * 948.784119;
            CGPoint screenPoint = CGPointMake(x, y);
            
            // TODO: rendering these anchors in 2D screen space
            
            // TODO: get the depth map and give each landmark correct z value in world coordinate
            
            
            // solving the depth problem
            //NSLog(@"%f %f %f", landmark.x, landmark.y, landmark.z);
            //NSLog(@"z value: %f", landmark.z);
            if(landmark.z < _landmarkZMin) {
                _landmarkZMin = landmark.z;
            }
            if(landmark.z > _landmarkZMax) {
                _landmarkZMax = landmark.z;
            }
            //NSLog(@"%f %f %f", landmark.x, landmark.y, landmark.z);
            //NSLog(@"Landmark Z Min is: %f", _landmarkZMin);
            //NSLog(@"Landmakr Z Max is: %f", _landmarkZMax);

            
            
            simd_float4x4 translation = matrix_identity_float4x4;
            // set z values for different landmarks
            translation.columns[3].z = -0.2;
            // TODO: find a better constant
            float handDepthConstant = 0.13 / 0.75;
            // the z value of the wrist landmark is temporarily fixed
            if (idx != 0) {
                translation.columns[3].z += landmark.z * handDepthConstant;
            }
            idx++;
            
            simd_float4x4 planeOrigin = simd_mul(currentFrame.camera.transform, translation);
            simd_float3 xAxis = simd_make_float3(1, 0, 0);
            //simd_float4x4 rotation = simd_quaternion(0.5 * M_PI, xAxis);
            //NSLog(@"%f", simd_quaternion(0.5 * M_PI, xAxis).vector.x);
            //NSLog(@"%f", simd_quaternion(0.5 * M_PI, xAxis).vector.y);
            //NSLog(@"%f", simd_quaternion(0.5 * M_PI, xAxis).vector.z);
            //NSLog(@"%f", simd_quaternion(0.5 * M_PI, xAxis).vector.w);
            simd_float4x4 rotation = simd_matrix4x4(simd_quaternion(0.5 * M_PI, xAxis));
            //NSLog(@"rotation");
            //[MathHelper logMatrix4x4:rotation];
            simd_float4x4 plane = simd_mul(planeOrigin, rotation);
            // make sure this plane matrix is correct
            //[MathHelper logMatrix4x4:plane];
            //simd_float3 unprojectedPoint = [currentFrame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:currentFrame.camera.imageResolution];
            simd_float3 unprojectedPoint = [currentFrame.camera unprojectPoint:screenPoint ontoPlaneWithTransform:plane orientation:UIInterfaceOrientationLandscapeRight viewportSize:CGSizeMake(1160.729858, 948.784119)];
            //NSLog(@"image resolution: %d %d", (int)currentFrame.camera.imageResolution.width, (int)currentFrame.camera.imageResolution.height);
            // TODO: if unprojectedPoint is nil?
            simd_float4x4 tempTransform = matrix_identity_float4x4;
            tempTransform.columns[3].x = unprojectedPoint.x;
            tempTransform.columns[3].y = unprojectedPoint.y;
            tempTransform.columns[3].z = unprojectedPoint.z;
            simd_float4x4 landmarkTransform = simd_mul(currentFrame.camera.transform, tempTransform);
            
            // manually set anchor's transform in screen space
            //landmarkTransform.columns[0].x = x;
            //landmarkTransform.columns[0].y = y;
            
            ARAnchor *anchor = [[ARAnchor alloc] initWithName:@"handtracking" transform:tempTransform];
            
            [_session addAnchor:anchor];
        }
    }
}

- (void)handTracker: (HandTracker*)handTracker didOutputHandednesses: (NSArray<Handedness *> *)handednesses {
    
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer {
    
}

@end
