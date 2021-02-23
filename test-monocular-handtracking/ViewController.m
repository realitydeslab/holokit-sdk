//
//  ViewController.m
//  test-monocular-handtracking
//
//  Created by Yuchen on 2021/2/21.
//

#import "ViewController.h"
#import "Renderer.h"

@interface ViewController () <MTKViewDelegate, ARSessionDelegate>

@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) Renderer *renderer;

@end


@interface MTKView () <RenderDestinationProvider>

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    [self.renderer update];
}

#pragma mark - ARSessionDelegate

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
