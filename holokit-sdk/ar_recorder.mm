//
//  ar_recorder.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/8/2.
//

#import "ar_recorder.h"
#import "holokit_api.h"

@interface HoloKitARRecorder()

@property (assign) bool isRecordingStarted;
@property (assign) bool isRecordingFinished;
@property (nonatomic, strong) NSString *videoPath;

@end

// Reference: https://github.com/AFathi/ARVideoKit
@implementation HoloKitARRecorder

- (instancetype)init {
    NSLog(@"[ar_recorder]: init");
    self = [super init];
    if (self) {
        NSError *error = nil;
        self.writer = [[AVAssetWriter alloc] initWithURL:[self newVideoPath] fileType:AVFileTypeMPEG4 error:&error];
        if (self.writer == nil) {
            NSLog(@"[ar_recorder]: failed to init AVAssetWriter.");
            return self;
        }
        
        NSDictionary *videoOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                             AVVideoCodecTypeHEVC, AVVideoCodecKey,
                                             [NSNumber numberWithInt:holokit::HoloKitApi::GetInstance()->GetScreenWidth()], AVVideoWidthKey,
                                             [NSNumber numberWithInt:holokit::HoloKitApi::GetInstance()->GetScreenHeight()], AVVideoHeightKey,
                                             nil];
        self.writerInput = [AVAssetWriterInput
                            assetWriterInputWithMediaType:AVMediaTypeVideo
                            outputSettings:videoOutputSettings];
        if (self.writerInput == nil) {
            NSLog(@"[ar_recorder]: failed to init AVAssetWriterInput.");
            return self;
        }
        self.writerInput.expectsMediaDataInRealTime = YES;
        
        self.writerInputPixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput sourcePixelBufferAttributes:nil];
        if (self.writerInputPixelBufferAdaptor == nil) {
            NSLog(@"[ar_recorder]: failed to init AVAssetWriterInputPixelBufferAdaptor.");
            return self;
        }
        
        if ([self.writer canAddInput:self.writerInput]) {
            [self.writer addInput:self.writerInput];
        } else {
            NSLog(@"[ar_recorder]: cannot add AVAssetWriterInput.");
            return self;
        }
        self.writer.shouldOptimizeForNetworkUse = NO;
        NSLog(@"[ar_recorder]: recorder successfully initialized.");
        self.isRecordingStarted = NO;
        self.isRecordingFinished = NO;
    }
    return self;
}

- (NSURL *)newVideoPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentDirectory = paths[0];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterFullStyle;
    formatter.timeStyle = NSDateFormatterFullStyle;
    formatter.dateFormat = @"yyyy-MM-dd'@'HH-mm-ssZZZZ";
    
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970: [[NSDate alloc] init].timeIntervalSince1970];
    NSString *videoPath = [NSString stringWithFormat:@"%@/%@%@", documentDirectory, [formatter stringFromDate:date], @"HoloKitReplay.mp4"];
    self.videoPath = videoPath;
    return [NSURL fileURLWithPath:videoPath isDirectory:NO];
}

- (void)insert:(CVPixelBufferRef)buffer with:(CMTime)time {
    NSLog(@"[ar_recorder]: insert");
    if (self.isRecordingFinished) return;
    //CMTime time = CMTimeMakeWithSeconds(intervals, 1000000);
    if (self.isRecordingStarted == NO) {
        if ([self.writer startWriting]) {
            [self.writer startSessionAtSourceTime:time];
            self.isRecordingStarted = YES;
            return;
        }
    }
    
    if (self.writerInput.isReadyForMoreMediaData) {
        NSLog(@"append pixel buffer");
        [self.writerInputPixelBufferAdaptor appendPixelBuffer:buffer withPresentationTime:time];
    }
}

- (void)end {
    NSLog(@"[ar_recorder]: end");
    self.isRecordingFinished = YES;
    [self.writerInput markAsFinished];
//    CMTime time = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000);
//    [self.writer endSessionAtSourceTime:time];
    [self.writer finishWritingWithCompletionHandler:^(void){
        NSLog(@"[ar_recorder]: recording finished successfully.");
        // https://stackoverflow.com/questions/35640815/writing-to-photos-library-with-avassetwriter
        UISaveVideoAtPathToSavedPhotosAlbum(self.videoPath, nil, nil, nil);
    }];
}

// Didn't work
+ (CVPixelBufferRef)convertIOSurfaceRefToCVPixelBufferRef:(IOSurfaceRef)surface {
    if (surface != nil) {
        NSLog(@"surface is not nil");
    }
    CVPixelBufferRef pixelBuffer;
    //NSDictionary *pixelBufferAttributes = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    //CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, (__bridge CFDictionaryRef _Nullable)(pixelBufferAttributes), &pixelBuffer);
    CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, nullptr, &pixelBuffer);
    if (pixelBuffer == nil) {
        NSLog(@"[ar_recorder]: converted pixel buffer is nil");
    }
    return pixelBuffer;
}

// https://liveupdate.tistory.com/445
+ (CVPixelBufferRef)convertMTLTextureToCVPixelBufferRef:(id<MTLTexture>)texture {
    //id<MTLTexture> convertedTexture = [texture newTextureViewWithPixelFormat: kCVPixelFormatType_422YpCbCr8BiPlanarFullRange];
    //NSLog(@"%lu", texture.pixelFormat);
    //NSLog(@"%lu", convertedTexture.pixelFormat);
    CVPixelBufferRef pixelBuffer;
    
//    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
//                             [NSNumber numberWithBool:YES], kCVPixelBufferMetalCompatibilityKey,
//                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
//                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
//                             nil];
    
    CVPixelBufferCreate(kCFAllocatorDefault,
                        texture.width,
                        texture.height,
                        kCVPixelFormatType_32BGRA,
                        //kCVPixelFormatType_32RGBA,
                        //kCVPixelFormatType_422YpCbCr8BiPlanarFullRange,
                        //(__bridge CFDictionaryRef) options,
                        nil,
                        &pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    MTLRegion region = MTLRegionMake2D(0, 0, texture.width, texture.height);
    
    [texture getBytes:pixelBufferBytes bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:0];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return pixelBuffer;
}

@end
