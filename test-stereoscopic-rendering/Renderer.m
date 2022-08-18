//
//  Renderer.m
//  HoloKitStereoscopicRendering
//
//  Created by Yuchen on 2021/2/4.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>

#import "Renderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"
#import "MathHelper.h"

// The max number of command buffers in flight
static const NSUInteger kMaxBuffersInFlight = 3;

// The max number anchors our uniform buffer will hold
static const NSUInteger kMaxAnchorInstanceCount = 64;

// The 256 byte aligned size of our uniform structures
static const size_t kAlignedSharedUniformsSize = (sizeof(SharedUniforms) & ~0xFF) + 0x100;
static const size_t kAlignedInstanceUniformsSize = ((sizeof(InstanceUniforms) * kMaxAnchorInstanceCount) & ~0xFF) + 0x100;

// Vertex data for an image plane
static const float kImagePlaneVertexData[16] = {
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
};

// Vertex data for the alignment marker
static const float kAlignmentMarkerVertexData[8] = {
    0.829760, 1, 0.0, 1.0,
    0.829760, 0.7, 0.0, 1.0
};

// for SR
const float kUserInterpupillaryDistance = 0.064;

@implementation Renderer {
    
    // The session the renderer will render
    ARSession *_session;
    
    // The object controlling the ultimate render destination
    __weak id<RenderDestinationProvider> _renderDestination;
    
    // Q?
    dispatch_semaphore_t _inFlightSemaphore;

    // Metal objects
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLBuffer> _sharedUniformBuffer;
    id <MTLBuffer> _anchorUniformBuffer;
    id <MTLBuffer> _imagePlaneVertexBuffer;
    id <MTLBuffer> _alignmentMarkerVertexBuffer;
    id <MTLRenderPipelineState> _capturedImagePipelineState;
    id <MTLDepthStencilState> _capturedImageDepthState;
    id <MTLRenderPipelineState> _anchorPipelineState;
    id <MTLDepthStencilState> _anchorDepthState;
    id <MTLRenderPipelineState> _alignmentMarkerPipelineState;
    id <MTLDepthStencilState> _alignmentMarkerDepthState;
    CVMetalTextureRef _capturedImageTextureYRef;
    CVMetalTextureRef _capturedImageTextureCbCrRef;
    // for depth data
    CVMetalTextureRef _depthTextureRef;
    CVMetalTextureRef _confidenceTextureRef;
    //id <MTLTexture> _filteredDepthTexture;
    
    // dual viewports
    MTLViewport _viewportPerEye[2];
    
    // Captured image texture cache
    CVMetalTextureCacheRef _capturedImageTextureCache;
    
    // Metal vertex descriptor specifying how vertices will by laid out for input into our
    //   anchor geometry render pipeline and how we'll layout our Model IO vertices
    MTLVertexDescriptor *_geometryVertexDescriptor;
    
    // MetalKit mesh containing vertex data and index buffer for our anchor geometry
    MTKMesh *_cubeMesh;
    
    // Used to determine _uniformBufferStride each frame.
    //   This is the current frame number modulo kMaxBuffersInFlight
    uint8_t _uniformBufferIndex;
    
    // Offset within _sharedUniformBuffer to set for the current frame
    uint32_t _sharedUniformBufferOffset;
    
    // Offset within _anchorUniformBuffer to set for the current frame
    uint32_t _anchorUniformBufferOffset;
    
    // Addresses to write shared uniforms to each frame
    void *_sharedUniformBufferAddress;
    
    // Addresses to write anchor uniforms to each frame
    void *_anchorUniformBufferAddress;
    
    // The number of anchor instances to render
    NSUInteger _anchorInstanceCount;
    
    // The current viewport size
    CGSize _viewportSize;
    
    // Flag for viewport size changes
    BOOL _viewportSizeDidChange;
    
    // Q?
    CGSize _drawableSize;
}

- (instancetype)initWithSession:(ARSession *)session metalDevice:(id<MTLDevice>)device renderDestinationProvider:(id<RenderDestinationProvider>)renderDestinationProvider {
    self = [super init];
    if (self) {
        _session = session;
        _device = device;
        _renderDestination = renderDestinationProvider;
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        [self _loadMetal];
        [self _loadAssets];
    }
    
    return self;
}

- (void)dealloc {
    CVBufferRelease(_capturedImageTextureYRef);
    CVBufferRelease(_capturedImageTextureCbCrRef);
    CVBufferRelease(_depthTextureRef);
    CVBufferRelease(_confidenceTextureRef);
}

- (void)drawRectResized:(CGSize)size drawableSize:(CGSize)drawableSize{
    _viewportSize = size;
    
    _drawableSize = drawableSize;
    _viewportSizeDidChange = YES;
}

- (void)update {
    // Wait to ensure only kMaxBuffersInFlight are getting processed by any stage in the Metal
    //   pipeline (App, Metal, Drivers, GPU, etc)
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    
    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Add completion handler which signal _inFlightSemaphore when Metal and the GPU has fully
    //   finished processing the commands we're encoding this frame.  This indicates when the
    //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
    //   and the GPU.
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    // Retain our CVMetalTextureRefs for the duration of the rendering cycle. The MTLTextures
    //   we use from the CVMetalTextureRefs are not valid unless their parent CVMetalTextureRefs
    //   are retained. Since we may release our CVMetalTextureRef ivars during the rendering
    //   cycle, we must retain them separately here.
    CVBufferRef capturedImageTextureYRef = CVBufferRetain(_capturedImageTextureYRef);
    CVBufferRef capturedImageTextureCbCrRef = CVBufferRetain(_capturedImageTextureCbCrRef);
    // TODO: don't know if this is good
    CVBufferRef depthTextureRef = CVBufferRetain(_depthTextureRef);
    CVBufferRef confidenceTextureRef = CVBufferRetain(_confidenceTextureRef);
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(block_sema);
        CVBufferRelease(capturedImageTextureYRef);
        CVBufferRelease(capturedImageTextureCbCrRef);
        CVBufferRelease(depthTextureRef);
        CVBufferRelease(confidenceTextureRef);
    }];
    
    [self _updateBufferStates];
    [self _updateGameState];
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor* renderPassDescriptor = _renderDestination.currentRenderPassDescriptor;
    
    // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll skip
    //   any rendering this frame because we have no drawable to draw to
    if (renderPassDescriptor != nil) {
        
        // Create a render command encoder so we can render into something
        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        [self _drawCapturedImageWithCommandEncoder:renderEncoder];
        [self _drawAnchorGeometryWithCommandEncoder:renderEncoder];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
    }
    
    // Schedule a present once the framebuffer is complete using the current drawable
    [commandBuffer presentDrawable:_renderDestination.currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

#pragma mark - Private

- (void)_loadMetal {
    // Create and load our basic Metal state objects
    
    // Set the default formats needed to render
    _renderDestination.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _renderDestination.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _renderDestination.sampleCount = 1;
    
    // for SR
    //_drawableSize = CGSizeMake(2778.0, 1284.0);
    
    // Calculate our uniform buffer sizes. We allocate kMaxBuffersInFlight instances for uniform
    //   storage in a single buffer. This allows us to update uniforms in a ring (i.e. triple
    //   buffer the uniforms) so that the GPU reads from one slot in the ring wil the CPU writes
    //   to another. Anchor uniforms should be specified with a max instance count for instancing.
    //   Also uniform storage must be aligned (to 256 bytes) to meet the requirements to be an
    //   argument in the constant address space of our shading functions.
    const NSUInteger sharedUniformBufferSize = kAlignedSharedUniformsSize * kMaxBuffersInFlight;
    const NSUInteger anchorUniformBufferSize = kAlignedInstanceUniformsSize * kMaxBuffersInFlight;
    
    // Create and allocate our uniform buffer objects. Indicate shared storage so that both the
    //   CPU can access the buffer
    _sharedUniformBuffer = [_device newBufferWithLength:sharedUniformBufferSize
                                                options:MTLResourceStorageModeShared];
    
    _sharedUniformBuffer.label = @"SharedUniformBuffer";
    
    _anchorUniformBuffer = [_device newBufferWithLength:anchorUniformBufferSize options:MTLResourceStorageModeShared];
    
    _anchorUniformBuffer.label = @"AnchorUniformBuffer";
    
    // Create a vertex buffer with our image plane vertex data.
    _imagePlaneVertexBuffer = [_device newBufferWithBytes:&kImagePlaneVertexData length:sizeof(kImagePlaneVertexData) options:MTLResourceCPUCacheModeDefaultCache];
    
    _imagePlaneVertexBuffer.label = @"ImagePlaneVertexBuffer";
    
    // Create a vertex buffer with our alignment marker vertex data.
    _alignmentMarkerVertexBuffer = [_device newBufferWithBytes:&kAlignmentMarkerVertexData length:sizeof(kAlignmentMarkerVertexData) options:MTLResourceCPUCacheModeDefaultCache];
    _alignmentMarkerVertexBuffer.label = @"AlignmentMarkerVertexBuffer";
    
    // Load all the shader files with a metal file extension in the project
    id <MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    
    id <MTLFunction> capturedImageVertexFunction = [defaultLibrary newFunctionWithName:@"capturedImageVertexTransform"];
    id <MTLFunction> capturedImageFragmentFunction = [defaultLibrary newFunctionWithName:@"capturedImageFragmentShader"];
    
    // Create a vertex descriptor for our image plane vertex buffer
    MTLVertexDescriptor *imagePlaneVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // Positions.
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].offset = 0;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].bufferIndex = kBufferIndexMeshPositions;
    
    // Texture coordinates.
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].offset = 8;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].bufferIndex = kBufferIndexMeshPositions;
    
    // Position Buffer Layout
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stride = 16;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepRate = 1;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Create a pipeline state for rendering the captured image
    MTLRenderPipelineDescriptor *capturedImagePipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    capturedImagePipelineStateDescriptor.label = @"MyCapturedImagePipeline";
    capturedImagePipelineStateDescriptor.sampleCount = _renderDestination.sampleCount;
    capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction;
    capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction;
    capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor;
    // for SR
    capturedImagePipelineStateDescriptor.maxVertexAmplificationCount = 2;
    
    capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = _renderDestination.colorPixelFormat;
    capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = _renderDestination.depthStencilPixelFormat;
    capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = _renderDestination.depthStencilPixelFormat;
    
    NSError *error = nil;
    _capturedImagePipelineState = [_device newRenderPipelineStateWithDescriptor:capturedImagePipelineStateDescriptor error:&error];
    if (!_capturedImagePipelineState) {
        NSLog(@"Failed to created captured image pipeline state, error %@", error);
    }
    
    MTLDepthStencilDescriptor *capturedImageDepthStateDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    capturedImageDepthStateDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    capturedImageDepthStateDescriptor.depthWriteEnabled = NO;
    _capturedImageDepthState = [_device newDepthStencilStateWithDescriptor:capturedImageDepthStateDescriptor];
    
    // Create captured image texture cache
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_capturedImageTextureCache);
    
    id <MTLFunction> anchorGeometryVertexFunction = [defaultLibrary newFunctionWithName:@"anchorGeometryVertexTransform"];
    id <MTLFunction> anchorGeometryFragmentFunction = [defaultLibrary newFunctionWithName:@"anchorGeometryFragmentLighting"];
    
    // Create a vertex descriptor for our Metal pipeline. Specifies the layout of vertices the
    //   pipeline should expect. The layout below keeps attributes used to calculate vertex shader
    //   output position separate (world position, skinning, tweening weights) separate from other
    //   attributes (texture coordinates, normals).  This generally maximizes pipeline efficiency
    _geometryVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // Positions.
    _geometryVertexDescriptor.attributes[kVertexAttributePosition].format = MTLVertexFormatFloat3;
    _geometryVertexDescriptor.attributes[kVertexAttributePosition].offset = 0;
    _geometryVertexDescriptor.attributes[kVertexAttributePosition].bufferIndex = kBufferIndexMeshPositions;
    
    // Texture coordinates.
    _geometryVertexDescriptor.attributes[kVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _geometryVertexDescriptor.attributes[kVertexAttributeTexcoord].offset = 0;
    _geometryVertexDescriptor.attributes[kVertexAttributeTexcoord].bufferIndex = kBufferIndexMeshGenerics;
    
    // Normals.
    _geometryVertexDescriptor.attributes[kVertexAttributeNormal].format = MTLVertexFormatHalf3;
    _geometryVertexDescriptor.attributes[kVertexAttributeNormal].offset = 8;
    _geometryVertexDescriptor.attributes[kVertexAttributeNormal].bufferIndex = kBufferIndexMeshGenerics;
    
    // Position Buffer Layout
    _geometryVertexDescriptor.layouts[kBufferIndexMeshPositions].stride = 12;
    _geometryVertexDescriptor.layouts[kBufferIndexMeshPositions].stepRate = 1;
    _geometryVertexDescriptor.layouts[kBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Generic Attribute Buffer Layout
    _geometryVertexDescriptor.layouts[kBufferIndexMeshGenerics].stride = 16;
    _geometryVertexDescriptor.layouts[kBufferIndexMeshGenerics].stepRate = 1;
    _geometryVertexDescriptor.layouts[kBufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Create a reusable pipeline state for rendering anchor geometry
    MTLRenderPipelineDescriptor *anchorPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    anchorPipelineStateDescriptor.label = @"MyAnchorPipeline";
    anchorPipelineStateDescriptor.sampleCount = _renderDestination.sampleCount;
    anchorPipelineStateDescriptor.vertexFunction = anchorGeometryVertexFunction;
    anchorPipelineStateDescriptor.fragmentFunction = anchorGeometryFragmentFunction;
    anchorPipelineStateDescriptor.vertexDescriptor = _geometryVertexDescriptor;
    // for SR
    anchorPipelineStateDescriptor.maxVertexAmplificationCount = 2;
    anchorPipelineStateDescriptor.colorAttachments[0].pixelFormat = _renderDestination.colorPixelFormat;
    anchorPipelineStateDescriptor.depthAttachmentPixelFormat = _renderDestination.depthStencilPixelFormat;
    anchorPipelineStateDescriptor.stencilAttachmentPixelFormat = _renderDestination.depthStencilPixelFormat;
    
    _anchorPipelineState = [_device newRenderPipelineStateWithDescriptor:anchorPipelineStateDescriptor error:&error];
    if (!_anchorPipelineState) {
        NSLog(@"Failed to created geometry pipeline state, error %@", error);
    }
    
    MTLDepthStencilDescriptor *anchorDepthStateDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    anchorDepthStateDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    anchorDepthStateDescriptor.depthWriteEnabled = YES;
    _anchorDepthState = [_device newDepthStencilStateWithDescriptor:anchorDepthStateDescriptor];
    
    // Create the command queue
    _commandQueue = [_device newCommandQueue];
}

- (void)_loadAssets {
    // Create and load our assets into Metal objects including meshes and textures
    
    // Create a MetalKit mesh buffer allocator so that ModelIO will load mesh data directly into
    //   Metal buffers accessible by the GPU
    MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice: _device];
    
    // Create a Model IO vertexDescriptor so that we format/layout our model IO mesh vertices to
    //   fit our Metal render pipeline's vertex descriptor layout
    MDLVertexDescriptor *vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_geometryVertexDescriptor);
    
    // Indicate how each Metal vertex descriptor attribute maps to each ModelIO attribute
    vertexDescriptor.attributes[kVertexAttributePosition].name  = MDLVertexAttributePosition;
    vertexDescriptor.attributes[kVertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;
    vertexDescriptor.attributes[kVertexAttributeNormal].name    = MDLVertexAttributeNormal;
    
    // Use ModelIO to create a box mesh as our object
    MDLMesh *mesh = [MDLMesh newBoxWithDimensions:(vector_float3){.075, .075, .075}
                                            segments:(vector_uint3){1, 1, 1}
                                        geometryType:MDLGeometryTypeTriangles
                                       inwardNormals:NO
                                           allocator:metalAllocator];
    
    
    // Perform the format/relayout of mesh vertices by setting the new vertex descriptor in our
    //   Model IO mesh
    mesh.vertexDescriptor = vertexDescriptor;
    
    NSError *error = nil;
    
    // Create a MetalKit mesh (and submeshes) backed by Metal buffers
    _cubeMesh = [[MTKMesh alloc] initWithMesh:mesh device:_device error:&error];
    
    if(!_cubeMesh || error) {
        NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    }
}

- (void)_updateBufferStates {
    // Update the location(s) to which we'll write to in our dynamically changing Metal buffers for
    //   the current frame (i.e. update our slot in the ring buffer used for the current frame)
    
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;
    
    _sharedUniformBufferOffset = kAlignedSharedUniformsSize * _uniformBufferIndex;
    _anchorUniformBufferOffset = kAlignedInstanceUniformsSize * _uniformBufferIndex;
    
    _sharedUniformBufferAddress = ((uint8_t*)_sharedUniformBuffer.contents) + _sharedUniformBufferOffset;
    _anchorUniformBufferAddress = ((uint8_t*)_anchorUniformBuffer.contents) + _anchorUniformBufferOffset;
}

- (void)_updateGameState {
    // Update any game state
    
    ARFrame *currentFrame = _session.currentFrame;
    
    if (!currentFrame) {
        return;
    }
    
    [self _updateSharedUniformsWithFrame:currentFrame];
    [self _updateAnchorsWithFrame:currentFrame];
    [self _updateCapturedImageTexturesWithFrame:currentFrame];
    
    // Prepare the current frame's depth and confidence images for transfer to the GPU.
    [self _updateARDepthTextures:currentFrame];
    // TODO: pass the depth data to other classes
        
    if (_viewportSizeDidChange) {
        _viewportSizeDidChange = NO;
        
        [self _updateImagePlaneWithFrame:currentFrame];
    }
}

- (void)_updateSharedUniformsWithFrame:(ARFrame *)frame {
    
    // parameters for SR
    const struct PhoneModel phone = [Renderer initializePhoneModel];
    const struct HoloKitModel hme = [Renderer initializeHoloKitModel];
    
    const float centerX = 0.5 * phone.screenWidth + phone.centerLineOffset;
    const float centerY = phone.screenHeight - (hme.axisToBottom - phone.screenBottom);
    
    // TODO: I think there should be only 2 cushion offsets
    //const float fullWidth = hme.viewportOuter * 2 + hme.opticalAxisDistance + hme.viewportCushion * 4;
    const float fullWidth = hme.viewportOuter * 2 + hme.opticalAxisDistance + hme.viewportCushion * 2;
    const float width = hme.viewportOuter + hme.viewportInner + hme.viewportCushion * 2;
    const float height = hme.viewportTop + hme.viewportBottom + hme.viewportCushion * 2;
    
    const float ipd = kUserInterpupillaryDistance;
    const float near = hme.lensToEye;
    const float far = 1000.0;
    
    // math for left eye projection matrix
    matrix_float4x4 leftEyeProjectionMatrix = matrix_identity_float4x4;
    leftEyeProjectionMatrix.columns[0].x = 2 * near / width;
    leftEyeProjectionMatrix.columns[1].y = 2 * near / height;
    // TODO: modified
    leftEyeProjectionMatrix.columns[2].x = (fullWidth - ipd - width) / width;
    //leftEyeProjectionMatrix.columns[2].x = (fullWidth / 2 + ipd - hme.viewportCushion) / width;
    //NSLog(@"1: %f", (fullWidth - ipd - width));
    //NSLog(@"2: %f", (fullWidth / 2 + ipd - hme.viewportCushion));
    leftEyeProjectionMatrix.columns[2].y = (hme.viewportTop - hme.viewportBottom) / height;
    leftEyeProjectionMatrix.columns[2].z = -(far + near) / (far - near);
    leftEyeProjectionMatrix.columns[3].z = -(2.0 * far * near) / (far - near);
    leftEyeProjectionMatrix.columns[2].w = -1.0;
    // TODO: should this value be 0?
    leftEyeProjectionMatrix.columns[3].w = 0.0;
    //[MathHelper logMatrix4x4:leftEyeProjectionMatrix];
    
    // right eye projection matrix
    matrix_float4x4 rightEyeProjectionMatrix = leftEyeProjectionMatrix;
    // TODO: modified
    //rightEyeProjectionMatrix.columns[2].x = (width + ipd - fullWidth) / width;
    rightEyeProjectionMatrix.columns[2].x = -rightEyeProjectionMatrix.columns[2].x;
    //[MathHelper logMatrix4x4:rightEyeProjectionMatrix];
    
    //NSLog(@"%f, %f", _drawableSize.width, _drawableSize.height);
    // define left viewport and right viewport
    const double yMinInPixel = (double)((centerY - (hme.viewportTop + hme.viewportCushion)) / phone.screenHeight * (float)_drawableSize.height);
    const double xMinRightInPixel = (double)((centerX + fullWidth / 2 - width) / phone.screenWidth * (float)_drawableSize.width);
    const double xMinLeftInPixel = (double)((centerX - fullWidth / 2) / phone.screenWidth * (float)_drawableSize.width);
    
    const double widthInPixel = (double)(width / phone.screenWidth * (float)_drawableSize.width);
    const double heightInPixel = (double)(height / phone.screenHeight * (float)_drawableSize.height);
    
    //NSLog(@"drawable width %f and height %f", _drawableSize.width, _drawableSize.height);
    
    MTLViewport rightViewport;
    rightViewport.originX = xMinRightInPixel;
    rightViewport.originY = yMinInPixel;
    rightViewport.width = widthInPixel;
    rightViewport.height = heightInPixel;
    rightViewport.znear = 0;
    rightViewport.zfar = 1;
    MTLViewport leftViewport;
    leftViewport.originX = xMinLeftInPixel;
    leftViewport.originY = yMinInPixel;
    leftViewport.width = widthInPixel;
    leftViewport.height = heightInPixel;
    leftViewport.znear = 0;
    leftViewport.zfar = 1;
    //NSLog(@"leftViewport originX: %f, originY: %f, width: %f, height: %f, znear: %f, zfar: %f", leftViewport.originX, leftViewport.originY, leftViewport.width, leftViewport.height, leftViewport.znear, leftViewport.zfar);
    //NSLog(@"rightViewport originX: %f, originY: %f, width: %f, height: %f, znear: %f, zfar: %f", rightViewport.originX, rightViewport.originY, rightViewport.width, rightViewport.height, rightViewport.znear, rightViewport.zfar);
    
    _viewportPerEye[0] = leftViewport;
    _viewportPerEye[1] = rightViewport;
    
    // Update the shared uniforms of the frame
    SharedUniforms *uniforms = (SharedUniforms *)_sharedUniformBufferAddress;
    
    uniforms->viewMatrix = [frame.camera viewMatrixForOrientation:UIInterfaceOrientationLandscapeRight];
    uniforms->projectionMatrix = [frame.camera projectionMatrixForOrientation:UIInterfaceOrientationLandscapeRight viewportSize:_viewportSize zNear:0.001 zFar:1000];
    
    // for left and right view matrices for SR
    // pointing from the phone camera to the center of two eyes
    const simd_float3 offset = hme.mrOffset + phone.cameraOffset;
    // the world coordinate of the camera
    const simd_float4x4 cameraTransform = frame.camera.transform;

    //[Renderer logMatrix4x4:cameraTransform];
    const simd_float4 translation_left = [Renderer matrixVectorMultiplication:cameraTransform vector:simd_make_float4(offset.x - ipd / 2, offset.y, offset.z, 1)];
    // test the accuracy of the matrix vector multiplication function
    //[Renderer logVector4:translation_left];
    const simd_float4 translation_right = [Renderer matrixVectorMultiplication:cameraTransform vector:simd_make_float4(offset.x + ipd / 2, offset.y, offset.z, 1)];
    simd_float4x4 cameraTransform_left = cameraTransform;
    cameraTransform_left.columns[3] = translation_left;
    simd_float4x4 cameraTransform_right = cameraTransform;
    cameraTransform_right.columns[3] = translation_right;
    
    // update view and projection matrices for both eyes
    uniforms->viewMatrixPerEye[0] = simd_inverse(cameraTransform_left);
    uniforms->viewMatrixPerEye[1] = simd_inverse(cameraTransform_right);
    uniforms->projectionMatrixPerEye[0] = leftEyeProjectionMatrix;
    uniforms->projectionMatrixPerEye[1] = rightEyeProjectionMatrix;

    // Set up lighting for the scene using the ambient intensity if provided
    float ambientIntensity = 1.0;
    
    if (frame.lightEstimate) {
        ambientIntensity = frame.lightEstimate.ambientIntensity / 1000;
    }
    
    vector_float3 ambientLightColor = { 0.5, 0.5, 0.5 };
    uniforms->ambientLightColor = ambientLightColor * ambientIntensity;
    
    vector_float3 directionalLightDirection = { 0.0, 0.0, -1.0 };
    directionalLightDirection = vector_normalize(directionalLightDirection);
    uniforms->directionalLightDirection = directionalLightDirection;
    
    vector_float3 directionalLightColor = { 0.6, 0.6, 0.6 };
    uniforms->directionalLightColor = directionalLightColor * ambientIntensity;
    
    uniforms->materialShininess = 30;
}

- (void)_updateAnchorsWithFrame:(ARFrame *)frame {
    // Update the anchor uniform buffer with transforms of the current frame's anchors
    NSInteger anchorInstanceCount = MIN(frame.anchors.count, kMaxAnchorInstanceCount);
    
    NSInteger anchorOffset = 0;
    if (anchorInstanceCount == kMaxAnchorInstanceCount) {
        anchorOffset = MAX(frame.anchors.count - kMaxAnchorInstanceCount, 0);
    }
    
    for (NSInteger index = 0; index < anchorInstanceCount; index++) {
        InstanceUniforms *anchorUniforms = ((InstanceUniforms *)_anchorUniformBufferAddress) + index;
        ARAnchor *anchor = frame.anchors[index + anchorOffset];
        
        // Flip Z axis to convert geometry from right handed to left handed
        matrix_float4x4 coordinateSpaceTransform = matrix_identity_float4x4;
        coordinateSpaceTransform.columns[2].z = -1.0;
        
        anchorUniforms->modelMatrix = matrix_multiply(anchor.transform, coordinateSpaceTransform);
        
        // for handtracking anchors
        if ([anchor.name isEqual: @"handtracking"]) {
            anchorUniforms->anchorColor = simd_make_float4(0.0, 0.0, 1.0, 1.0);
        }
    }
    
    _anchorInstanceCount = anchorInstanceCount;
}

- (void)_updateCapturedImageTexturesWithFrame:(ARFrame *)frame {
    // Create two textures (Y and CbCr) from the provided frame's captured image
    CVPixelBufferRef pixelBuffer = frame.capturedImage;
    
    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
        return;
    }
    
    CVBufferRelease(_capturedImageTextureYRef);
    CVBufferRelease(_capturedImageTextureCbCrRef);
    _capturedImageTextureYRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatR8Unorm planeIndex:0];
    _capturedImageTextureCbCrRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatRG8Unorm planeIndex:1];
}

- (CVMetalTextureRef)_createTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer pixelFormat:(MTLPixelFormat)pixelFormat planeIndex:(NSInteger)planeIndex {
    
    const size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex);
    const size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex);
    
    CVMetalTextureRef mtlTextureRef = nil;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _capturedImageTextureCache, pixelBuffer, NULL, pixelFormat, width, height, planeIndex, &mtlTextureRef);
    if (status != kCVReturnSuccess) {
        CVBufferRelease(mtlTextureRef);
        mtlTextureRef = nil;
    }
    
    return mtlTextureRef;
}

#pragma mark - ARSceneDepth

// TODO: this is supposed to be non static
+ (void)setMTLPixelFormat:(MTLPixelFormat **)texturePixelFormat basedOn:(CVPixelBufferRef)pixelBuffer {
    if (CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32) {
        *texturePixelFormat = MTLPixelFormatR32Float;
        //NSLog(@"R32Float");
    } else if (CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_OneComponent8) {
        *texturePixelFormat = MTLPixelFormatR8Uint;
        //NSLog(@"R8Uint");
    } else {
        NSLog(@"Unsupported ARDepthData pixel-buffer format.");
    }
}

- (void)_updateARDepthTextures:(ARFrame *)frame {
    // Get the scene depth or smoothed scene depth from the current frame
    // TODO: what is the difference?
    //ARDepthData* sceneDepth = frame.smoothedSceneDepth;
    ARDepthData* sceneDepth = frame.sceneDepth;
    if (!sceneDepth){
        NSLog(@"Renderer");
        NSLog(@"Failed to acquire scene depth.");
        return;
    }
    CVPixelBufferRef pixelBuffer = sceneDepth.depthMap;
    
    MTLPixelFormat texturePixelFormat;
    //NSLog(@"depthMap");
    [Renderer setMTLPixelFormat:&texturePixelFormat basedOn:pixelBuffer];
    CVBufferRelease(_depthTextureRef);
    _depthTextureRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:texturePixelFormat planeIndex:0];
    
    pixelBuffer = sceneDepth.confidenceMap;
    //NSLog(@"confidenceMap");
    [Renderer setMTLPixelFormat:&texturePixelFormat basedOn:pixelBuffer];
    CVBufferRelease(_confidenceTextureRef);
    _confidenceTextureRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:texturePixelFormat planeIndex:0];
}

- (void)_updateImagePlaneWithFrame:(ARFrame *)frame {
    // Update the texture coordinates of our image plane to aspect fill the viewport
    CGAffineTransform displayToCameraTransform = CGAffineTransformInvert([frame displayTransformForOrientation:UIInterfaceOrientationLandscapeRight viewportSize:_viewportSize]);

    float *vertexData = [_imagePlaneVertexBuffer contents];
    for (NSInteger index = 0; index < 4; index++) {
        NSInteger textureCoordIndex = 4 * index + 2;
        CGPoint textureCoord = CGPointMake(kImagePlaneVertexData[textureCoordIndex], kImagePlaneVertexData[textureCoordIndex + 1]);
        CGPoint transformedCoord = CGPointApplyAffineTransform(textureCoord, displayToCameraTransform);
        vertexData[textureCoordIndex] = transformedCoord.x;
        vertexData[textureCoordIndex + 1] = transformedCoord.y;
    }
}

- (void)_drawAlignmentMarkerWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    [renderEncoder pushDebugGroup:@"DrawAlignmentMarker"];
    
}

- (void)_drawCapturedImageWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    if (_capturedImageTextureYRef == nil || _capturedImageTextureCbCrRef == nil) {
        return;
    }
    
    // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
    [renderEncoder pushDebugGroup:@"DrawCapturedImage"];
    // for stereoscopic rendering
    [renderEncoder setVertexAmplificationCount:2 viewMappings:nil];
    
    // Set render command encoder state
    [renderEncoder setCullMode:MTLCullModeNone];
    [renderEncoder setRenderPipelineState:_capturedImagePipelineState];
    [renderEncoder setDepthStencilState:_capturedImageDepthState];
    // for stereoscipic rendering (SR)
    [renderEncoder setViewports:_viewportPerEye count:2];
    
    // Set mesh's vertex buffers
    [renderEncoder setVertexBuffer:_imagePlaneVertexBuffer offset:0 atIndex:kBufferIndexMeshPositions];
    
    // Set any textures read/sampled from our render pipeline
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_capturedImageTextureYRef) atIndex:kTextureIndexY];
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_capturedImageTextureCbCrRef) atIndex:kTextureIndexCbCr];
    // for depth data
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_depthTextureRef) atIndex:3];
    [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_confidenceTextureRef) atIndex:4];
    
    // Draw each submesh of our mesh
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    //NSLog(@"Draw captured image...");
    
    [renderEncoder popDebugGroup];
}

- (void)_drawAnchorGeometryWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    if (_anchorInstanceCount == 0) {
        return;
    }
    
    // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
    [renderEncoder pushDebugGroup:@"DrawAnchors"];
    
    // for SR
    [renderEncoder setVertexAmplificationCount:2 viewMappings:nil];
    
    // Set render command encoder state
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setRenderPipelineState:_anchorPipelineState];
    [renderEncoder setDepthStencilState:_anchorDepthState];
    // for SR
    [renderEncoder setViewports:_viewportPerEye count:2];
    
    // Set any buffers fed into our render pipeline
    [renderEncoder setVertexBuffer:_anchorUniformBuffer offset:_anchorUniformBufferOffset atIndex:kBufferIndexInstanceUniforms];
    
    [renderEncoder setVertexBuffer:_sharedUniformBuffer offset:_sharedUniformBufferOffset atIndex:kBufferIndexSharedUniforms];
    
    [renderEncoder setFragmentBuffer:_sharedUniformBuffer offset:_sharedUniformBufferOffset atIndex:kBufferIndexSharedUniforms];
    
    
    // Set mesh's vertex buffers
    for (NSUInteger bufferIndex = 0; bufferIndex < _cubeMesh.vertexBuffers.count; bufferIndex++) {
        MTKMeshBuffer *vertexBuffer = _cubeMesh.vertexBuffers[bufferIndex];
        [renderEncoder setVertexBuffer:vertexBuffer.buffer offset:vertexBuffer.offset atIndex:bufferIndex];
    }
    
    // Draw each submesh of our mesh
    for(MTKSubmesh *submesh in _cubeMesh.submeshes) {
        [renderEncoder drawIndexedPrimitives:submesh.primitiveType indexCount:submesh.indexCount indexType:submesh.indexType indexBuffer:submesh.indexBuffer.buffer indexBufferOffset:submesh.indexBuffer.offset instanceCount:_anchorInstanceCount];
    }
    
    [renderEncoder popDebugGroup];
}

- (BOOL)supportsMultipleViewports {
    return [_device supportsFamily: MTLGPUFamilyMac1] || [_device supportsFamily: MTLGPUFamilyApple5];
}

+ (struct HoloKitModel)initializeHoloKitModel {
    struct HoloKitModel holoKitModel;
    holoKitModel.opticalAxisDistance = 0.064;
    holoKitModel.mrOffset = simd_make_float3(0, -0.02894, 0.07055);
    holoKitModel.distortion = 0.0;
    holoKitModel.viewportInner = 0.0292;
    holoKitModel.viewportOuter = 0.0292;
    holoKitModel.viewportTop = 0.02386;
    holoKitModel.viewportBottom = 0.02386;
    holoKitModel.focalLength = 0.065;
    holoKitModel.screenToLens = 0.02715 + 0.03136 + 0.002;
    holoKitModel.lensToEye = 0.02497 + 0.03898;
    holoKitModel.axisToBottom = 0.02990;
    holoKitModel.viewportCushion = 0.0000;
    holoKitModel.horizontalAlignmentMarkerOffset = 0.05075;
    
    return holoKitModel;
}

+ (struct PhoneModel)initializePhoneModel {
    struct PhoneModel phoneModel;
    //phoneModel.screenWidth = 0.13977;
    //phoneModel.screenHeight = 0.06458;
    //phoneModel.screenBottom = 0.00347;
    //phoneModel.centerLineOffset = 0.0;
    //phoneModel.cameraOffset = simd_make_float3(0.05996, -0.02364 - 0.03494, 0.00591);
    
    // iPhone12ProMax phone model
    phoneModel.screenWidth = 0.15390;
    phoneModel.screenHeight = 0.07113;
    phoneModel.screenBottom = 0.00347;
    phoneModel.centerLineOffset = 0.0;
    phoneModel.cameraOffset = simd_make_float3(0.066945, -0.061695, -0.0091);
    
    return phoneModel;
}

+ (simd_float4)matrixVectorMultiplication:(simd_float4x4)mat vector:(simd_float4)vec {
    simd_float4 ret;
    ret.x = mat.columns[0].x * vec.x + mat.columns[1].x * vec.y + mat.columns[2].x * vec.z + mat.columns[3].x * vec.w;
    ret.y = mat.columns[0].y * vec.x + mat.columns[1].y * vec.y + mat.columns[2].y * vec.z + mat.columns[3].y * vec.w;
    ret.z = mat.columns[0].z * vec.x + mat.columns[1].z * vec.y + mat.columns[2].z * vec.z + mat.columns[3].z * vec.w;
    ret.w = mat.columns[0].w * vec.x + mat.columns[1].w * vec.y + mat.columns[2].w * vec.z + mat.columns[3].w * vec.w;
    return ret;
}

+ (void)logVector4:(simd_float4)vec {
    NSLog(@"simd_float4: [%f %f %f %f]", vec.x, vec.y, vec.z, vec.w);
}

// print out the matrix column by column
+ (void)logMatrix4x4:(simd_float4x4)mat {
    NSLog(@"simd_float4x4;");
    NSLog(@"[%f %f %f %f]", mat.columns[0].x, mat.columns[0].y, mat.columns[0].z, mat.columns[0].w);
    NSLog(@"[%f %f %f %f]", mat.columns[1].x, mat.columns[1].y, mat.columns[1].z, mat.columns[1].w);
    NSLog(@"[%f %f %f %f]", mat.columns[2].x, mat.columns[2].y, mat.columns[2].z, mat.columns[2].w);
    NSLog(@"[%f %f %f %f]", mat.columns[3].x, mat.columns[3].y, mat.columns[3].z, mat.columns[3].w);
}

@end