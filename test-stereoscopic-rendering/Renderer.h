//
//  Renderer.h
//  HoloKitStereoscopicRendering
//
//  Created by Yuchen on 2021/2/4.
//

#import <Metal/Metal.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

/*
 Protocol abstracting the platform specific view in order to keep the Renderer
 class independent from platform.
 */
@protocol RenderDestinationProvider

@property (nonatomic, readonly, nullable) MTLRenderPassDescriptor *currentRenderPassDescriptor;
@property (nonatomic, readonly, nullable) id<MTLDrawable> currentDrawable;

@property (nonatomic) MTLPixelFormat colorPixelFormat;
@property (nonatomic) MTLPixelFormat depthStencilPixelFormat;
@property (nonatomic) NSUInteger sampleCount;

@end

struct HoloKitModel {
    // Q
    float opticalAxisDistance;
    // 3D offset from the center of the bottomline of the HoloKit phone display to the center of two eyes
    // x is right
    // y is up
    // z is backward
    // right-handed
    simd_float3 mrOffset;
    // Q
    float distortion;
    // Q
    float viewportInner;
    float viewportOuter;
    float viewportTop;
    float viewportBottom;
    float focalLength;
    float screenToLens;
    float lensToEye;
    float axisToBottom;
    float viewportCushion;
    float horizontalAlignmentMarkerOffset;
};

struct PhoneModel {
    float screenWidth;
    float screenHeight;
    float screenBottom;
    float centerLineOffset;
    simd_float3 cameraOffset;
};

/*
 The main class performing the rendering of a session.
 */
@interface Renderer : NSObject

- (instancetype)initWithSession:(ARSession *)session metalDevice:(id<MTLDevice>)device renderDestinationProvider:(id<RenderDestinationProvider>)renderDestinationProvider;

- (void)drawRectResized:(CGSize)size drawableSize:(CGSize)drawableSize;

- (void)update;

// test for support
- (BOOL)supportsMultipleViewports;

- (CVMetalTextureRef)depthTextureRef;

+ (struct HoloKitModel)initializeHoloKitModel;

+ (struct PhoneModel)initializePhoneModel;

+ (void)setMTLPixelFormat:(MTLPixelFormat **)texturePixelFormat basedOn:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
