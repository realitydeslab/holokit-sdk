// SPDX-FileCopyrightText: Copyright 2023 Holo Interactive <dev@holoi.com>
// SPDX-FileContributor: Botao Amber Hu <botao@holoi.com>
// SPDX-License-Identifier: MIT

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#import <AVFoundation/AVFoundation.h>

static AVAssetWriter* _writer;
static AVAssetWriterInput* _videoWriterInput;
static AVAssetWriterInput* _audioWriterInput;
static AVAssetWriterInputPixelBufferAdaptor* _bufferAdaptor;

extern void HoloKitVideoRecorder_StartRecording(const char* filePath, int width, int height, float bitrate) {
    if (_writer)
       {
           NSLog(@"Recording has already been initiated.");
           return;
       }

       // Asset writer setup
       NSURL* filePathURL =
         [NSURL fileURLWithPath:[NSString stringWithUTF8String:filePath]];

       NSError* err;
       _writer =
         [[AVAssetWriter alloc] initWithURL: filePathURL
                                   fileType: AVFileTypeQuickTimeMovie
                                      error: &err];

       if (err)
       {
           NSLog(@"Failed to initialize AVAssetWriter (%@)", err);
           return;
       }
    
       // Asset writer input setup
        NSDictionary* compressionSettings = @{
            AVVideoAverageBitRateKey: @(bitrate),
            AVVideoMaxKeyFrameIntervalKey: @(30)
        };
    
       NSDictionary* settings =
         @{ AVVideoCodecKey: AVVideoCodecTypeHEVC,
            AVVideoWidthKey: @(width),
            AVVideoHeightKey: @(height),
            AVVideoCompressionPropertiesKey: compressionSettings};

    
        _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeVideo outputSettings: settings];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
    
        // Pixel buffer adaptor setup
        NSDictionary* attribs =
          @{ (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                       (NSString*)kCVPixelBufferWidthKey: @(width),
                      (NSString*)kCVPixelBufferHeightKey: @(height) };

        _bufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
             assetWriterInputPixelBufferAdaptorWithAssetWriterInput: _videoWriterInput
                                        sourcePixelBufferAttributes: attribs];
        

        NSDictionary *audioSettings = @{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVSampleRateKey: @44100,
            AVNumberOfChannelsKey: @2,
        };
        _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];

        [_writer addInput:_videoWriterInput];
        [_writer addInput:_audioWriterInput];
        
       // Recording start
       if (![_writer startWriting])
       {
           NSLog(@"Failed to start (%ld: %@)", _writer.status, _writer.error);
           return;
       }

       [_writer startSessionAtSourceTime:kCMTimeZero];
}

extern void HoloKitVideoRecorder_AppendAudioFrame(const void* source, uint32_t size, double time)
{
    if (!_writer)
    {
        NSLog(@"Recording hasn't been initiated.");
        return;
    }

    if (!_audioWriterInput.isReadyForMoreMediaData)
    {
        NSLog(@"Audio Writer is not ready.");
        return;
    }
    
    CMBlockBufferRef blockBuffer = NULL;
    CMBlockBufferCreateWithMemoryBlock(
        kCFAllocatorDefault,
        source, // memoryBlock to hold the copied data
        size, // size of the memory block in bytes
        kCFAllocatorNull, // blockAllocator
        NULL, // customBlockSource
        0, // offsetToData
        size, // dataLength
        0, // flags
        &blockBuffer);

    CMSampleBufferRef sampleBuffer = NULL;
    
    CMTime presentationTimestamp = CMTimeMakeWithSeconds(time, 240); // Adjust timescale as needed
    CMSampleTimingInfo sampleTiming = {
       .duration = kCMTimeInvalid,
       .presentationTimeStamp = presentationTimestamp,
       .decodeTimeStamp = kCMTimeInvalid
   };
    
    OSStatus status = CMSampleBufferCreateReady(
        kCFAllocatorDefault,
        blockBuffer, // CMBlockBuffer
        formatDescription, // formatDescription
        1, // numSamples
        1, // numSampleTimingEntries
        &sampleTiming, // sampleTimingArray
        0, // numSampleSizeEntries
        NULL, // sampleSizeArray
        &sampleBuffer);
    

    if (status != noErr) {
        CFRelease(blockBuffer);
        return;
    }
    
    [_audioInputWriter appendSampleBuffer:sampleBuffer];

    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}
extern void HoloKitVideoRecorder_AppendVideoFrame(const void* source, uint32_t size, double time)
{
    if (!_writer)
    {
        NSLog(@"Recording hasn't been initiated.");
        return;
    }

    if (!_videoWriterInput.isReadyForMoreMediaData)
    {
        NSLog(@"Video Writer is not ready.");
        return;
    }
    
    // Buffer allocation
    CVPixelBufferRef buffer;
    CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(NULL, _bufferAdaptor.pixelBufferPool, &buffer);

    if (ret != kCVReturnSuccess)
    {
        NSLog(@"Can't allocate a pixel buffer (%d)", ret);
        NSLog(@"%ld: %@", _writer.status, _writer.error);
        return;
    }

    // Buffer update
    CVPixelBufferLockBaseAddress(buffer, 0);

    void* pointer = CVPixelBufferGetBaseAddress(buffer);
    size_t buffer_size = CVPixelBufferGetDataSize(buffer);
    memcpy(pointer, source, MIN(size, buffer_size));

    CVPixelBufferUnlockBaseAddress(buffer, 0);

    // Buffer submission
    [_bufferAdaptor appendPixelBuffer:buffer
                 withPresentationTime:CMTimeMakeWithSeconds(time, 240)];

    CVPixelBufferRelease(buffer);
}

extern void HoloKitVideoRecorder_EndRecording(void)
{
    if (!_writer)
    {
        NSLog(@"Recording hasn't been initiated.");
        return;
    }

    [_videoWriterInput markAsFinished];
    [_audioWriterInput markAsFinished];
    
#if TARGET_OS_IOS

    NSString* path = _writer.outputURL.path;
    [_writer finishWritingWithCompletionHandler: ^{
        UISaveVideoAtPathToSavedPhotosAlbum(path, nil, nil, nil);
    }];

#else

    [_writer finishWritingWithCompletionHandler: ^{}];

#endif

    _writer = NULL;
    _videoWriterInput = NULL;
    _audioWriterInput = NULL;
    _bufferAdaptor = NULL;
}
