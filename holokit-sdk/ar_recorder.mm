//
//  ar_recorder.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/8/2.
//

#import "ar_recorder.h"
#import "holokit_api.h"

@interface ARRecorder()

@property (assign) bool isRecordingStarted;
@property (nonatomic, strong) NSString *videoPath;

@end

@implementation ARRecorder

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
                                             AVVideoCodecTypeH264, AVVideoCodecKey,
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
        self.isRecordingStarted = false;
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
    //CMTime time = CMTimeMakeWithSeconds(intervals, 1000000);
    if (self.isRecordingStarted == false) {
        if ([self.writer startWriting]) {
            [self.writer startSessionAtSourceTime:time];
            self.isRecordingStarted = true;
        }
    }
    
    if (self.writerInput.isReadyForMoreMediaData) {
        NSLog(@"append pixel buffer");
        [self.writerInputPixelBufferAdaptor appendPixelBuffer:buffer withPresentationTime:time];
    }
}

- (void)end {
    NSLog(@"[ar_recorder]: end");
    [self.writer finishWritingWithCompletionHandler:^(void){
        NSLog(@"[ar_recorder]: recording finished successfully.");
        // https://stackoverflow.com/questions/35640815/writing-to-photos-library-with-avassetwriter
        UISaveVideoAtPathToSavedPhotosAlbum(self.videoPath, nil, nil, nil);
    }];
}

@end
