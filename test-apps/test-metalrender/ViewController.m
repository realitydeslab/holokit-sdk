//
//  ViewController.m
//  test-metalrender
//
//  Created by Botao Hu on 10/16/20.
//

#import "ViewController.h"
#import "Renderer.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController () <MTKViewDelegate, ARSessionDelegate>

@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) Renderer *renderer;
@end


@interface MTKView () <RenderDestinationProvider>

@end


@implementation ViewController

CMMotionManager *_motionManager;
static const NSTimeInterval kAccelerometerUpdateInterval = 0.001;
static const NSTimeInterval kGyroUpdateInterval = 0.01;
NSOperationQueue *_queue;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _motionManager = [[CMMotionManager alloc] init];
    _queue = [[NSOperationQueue alloc] init];
    // Tune these to your performance prefs.
    // maxConcurrent set to anything >1 crashes HoloKit SDK.
    _queue.maxConcurrentOperationCount = 1;
    if ([_queue respondsToSelector:@selector(setQualityOfService:)]) {
      // Use highest quality of service.
      _queue.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    
    _motionManager.accelerometerUpdateInterval = kAccelerometerUpdateInterval;
    [_motionManager
        startAccelerometerUpdatesToQueue:_queue
                             withHandler:^(CMAccelerometerData *accelerometerData,
                                           NSError *error) {
        NSLog(@"accelerometerData.timestamp: %f,  systemuptime: %f", accelerometerData.timestamp, [[NSProcessInfo processInfo] systemUptime]);
        
                             }];
    
    _motionManager.deviceMotionUpdateInterval = kGyroUpdateInterval;
    [_motionManager
        startDeviceMotionUpdatesToQueue:_queue
                            withHandler:^(CMDeviceMotion *motionData, NSError *error) {
        NSLog(@"motionData.timestamp: %f,  systemuptime: %f", motionData.timestamp, [[NSProcessInfo processInfo] systemUptime]);
                            }];
    
    // Create an ARSession
    self.session = [ARSession new];
    self.session.delegate = self;
    
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
    NSLog(@"%@", NSStringFromCGRect(view.bounds));
    [self.renderer drawRectResized:view.bounds.size];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    NSMutableArray *gestureRecognizers = [NSMutableArray array];
    [gestureRecognizers addObject:tapGesture];
    [gestureRecognizers addObjectsFromArray:view.gestureRecognizers];
    view.gestureRecognizers = gestureRecognizers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];

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
    [self.renderer drawRectResized:view.bounds.size];
}

// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view {
    NSLog(@"update start; systemuptime: %f", [[NSProcessInfo processInfo] systemUptime]);
    [self.renderer update];
    NSLog(@"update done; systemuptime: %f", [[NSProcessInfo processInfo] systemUptime]);
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
//    frame.camera.transform
//    frame.camera.intrinsics
    NSLog(@"frame.timestamp: %f,  systemuptime: %f", frame.timestamp, [[NSProcessInfo processInfo] systemUptime]);
    
//    [[NSProcessInfo processInfo] systemUptime]
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

@end
