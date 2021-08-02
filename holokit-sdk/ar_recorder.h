//
//  ar_recorder.h
//  holokit
//
//  Created by Yuchen on 2021/8/2.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface ARRecorder : NSObject

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *writerInputPixelBufferAdaptor;

- (NSURL *)newVideoPath;
- (void)insert:(CVPixelBufferRef)buffer with:(CMTime)time;
- (void)end;
+ (CVPixelBufferRef)convertIOSurfaceRefToCVPixelBufferRef:(IOSurfaceRef)surface;
+ (CVPixelBufferRef)convertMTLTextureToCVPixelBufferRef:(id<MTLTexture>)texture;

@end
