// SPDX-FileCopyrightText: Copyright 2023 Holo Interactive <dev@holoi.com>
// SPDX-FileContributor: Botao Amber Hu <botao@holoi.com>
// SPDX-License-Identifier: MIT

#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#include <CoreMedia/CMBlockBuffer.h>

static AVAssetWriter* _writer;
static AVAssetWriterInput* _videoWriterInput;
static AVAssetWriterInput* _audioWriterInput;
static AVAssetWriterInputPixelBufferAdaptor* _bufferAdaptor;
static AudioStreamBasicDescription _audioFormat;
static CMFormatDescriptionRef _cmFormat;

static bool _isRecording;
static size_t _width;
static size_t _height;

extern "C" {

void HoloKitVideoRecorder_StartRecording(const char* filePath, size_t width, size_t height,
                                        float audioSampleRate, size_t audioChannelCount,
                                        float videoBitRate, float audioBitRate) {
    if (_writer)
    {
        NSLog(@"Recording has already been initiated.");
        return;
    }
    
    // Asset writer setup
    NSURL* filePathURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:filePath]];
    
    NSError* err;
    _writer = [[AVAssetWriter alloc] initWithURL: filePathURL
                                        fileType: AVFileTypeMPEG4
                                           error: &err];
    
    if (err)
    {
        NSLog(@"Failed to initialize AVAssetWriter (%@)", err);
        return;
    }
    
    // Video writer input setup
    // NSDictionary* compressionSettings = @{
    //     AVVideoAverageBitRateKey: @(videoBitRate),
    //     AVVideoMaxKeyFrameIntervalKey: @(30)
    // };
    
    NSDictionary* settings = @{ 
        AVVideoCodecKey: AVVideoCodecTypeHEVC,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height) };
//        AVVideoCompressionPropertiesKey: compressionSettings};
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeVideo outputSettings: settings];
    _videoWriterInput.expectsMediaDataInRealTime = YES;

    // Pixel buffer adaptor setup
    NSDictionary* attribs = @{ 
        (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString*)kCVPixelBufferWidthKey: @(width),
        (NSString*)kCVPixelBufferHeightKey: @(height) };
    
    _bufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
                      assetWriterInputPixelBufferAdaptorWithAssetWriterInput: _videoWriterInput
                      sourcePixelBufferAttributes: attribs];
    
    // Audio writer input setup
    NSDictionary* audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(audioSampleRate),
        AVNumberOfChannelsKey: @(audioChannelCount),
        AVEncoderBitRateKey: @(audioBitRate)
    };
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                         outputSettings:audioSettings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    
    _audioFormat.mSampleRate = audioSampleRate; // Sample rate, 44100Hz is CD quality
    _audioFormat.mFormatID = kAudioFormatLinearPCM; // Specify the data format to be PCM
    _audioFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat; // Flags specific for the format
    _audioFormat.mFramesPerPacket = 1; // Each packet contains one frame for PCM data
    _audioFormat.mChannelsPerFrame = (uint32_t) audioChannelCount; // Set the number of channels
    _audioFormat.mBitsPerChannel = sizeof(float) * 8; // Number of bits per channel, 32 for float
    _audioFormat.mBytesPerFrame = (uint32_t) audioChannelCount * sizeof(float); // Bytes per frame
    _audioFormat.mBytesPerPacket = _audioFormat.mBytesPerFrame * _audioFormat.mFramesPerPacket; // Bytes per packet
    CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                               &_audioFormat,
                               0,
                               NULL,
                               0,
                               NULL,
                               NULL,
                               &_cmFormat
                               );

    [_writer addInput:_videoWriterInput];
    [_writer addInput:_audioWriterInput];
    
    // Recording start
    if (![_writer startWriting])
    {
        NSLog(@"Failed to start (%ld: %@)", _writer.status, _writer.error);
        return;
    }

    _width = width;
    _height = height;
    [_writer startSessionAtSourceTime:kCMTimeZero];
    _isRecording = YES;  
}

void HoloKitVideoRecorder_AppendAudioFrame(void* source, size_t size, double time)
{
    if (!_isRecording) {
        return;
    }

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

    // Write _audioInputWriter with buffer 

    CMTime presentationTimestamp = CMTimeMakeWithSeconds(time, 240); // Adjust timescale as needed
    
    CMBlockBufferRef blockBuffer;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         source,
                                                         size, kCFAllocatorNull, NULL, 0, size, kCMBlockBufferAssureMemoryNowFlag, &blockBuffer);
    
    if (status != noErr) {
        NSLog(@"CMBlockBufferCreateWithMemoryBlock error");
        return;
    }

    size_t nSamples = size / _audioFormat.mBytesPerFrame;

    CMSampleBufferRef sampleBuffer;
    status = CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
                                                             blockBuffer,
                                                             TRUE,
                                                             NULL,
                                                             NULL,
                                                             _cmFormat,
                                                             nSamples,
                                                             presentationTimestamp,
                                                             NULL,
                                                             &sampleBuffer);
    
    if (status != noErr) {
        CFRelease(blockBuffer);
        return;
    }

    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"sample buffer is not ready");
        return;
    }
    if (!CMSampleBufferIsValid(sampleBuffer))
    {
        NSLog(@"Audio sapmle buffer is not valid");
        return;
    }
    
    status = CMSampleBufferMakeDataReady(sampleBuffer);
    if (status == noErr) {
        [_audioWriterInput appendSampleBuffer:sampleBuffer];
    }
    
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}

void HoloKitVideoRecorder_AppendVideoFrame(const char* source, uint32_t size, double time)
{
    if (!_isRecording) {
        return;
    }

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
    
    if (!_bufferAdaptor.pixelBufferPool)
    {
        NSLog(@"Video Writer pixelBufferPool is empty.");
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
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    size_t buffer_size = CVPixelBufferGetDataSize(buffer);
    memcpy(pointer, source, MIN(buffer_size, size));
    printf(bytesPerRow == _width * sizeof(float) * 4);

    // for (unsigned long y = 0; y < _height; y++) {
    //    memcpy((char*) pointer + bytesPerRow * (_height - y - 1), source + _width * y * 4, _width * 4);
    // }

    // MTLRegion region = MTLRegionMake2D(0, 0, _width, _height);
    
    // id<MTLTexture> texture = (__bridge id<MTLTexture>)(texture_ptr);
    // [texture getBytes:pointer bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:0];

    CVPixelBufferUnlockBaseAddress(buffer, 0);

    // Buffer submission
    [_bufferAdaptor appendPixelBuffer:buffer
                    withPresentationTime:CMTimeMakeWithSeconds(time, 240)];
    
    CVPixelBufferRelease(buffer);
}

void HoloKitVideoRecorder_EndRecording(void)
{
    if (!_isRecording) {
        return;
    }

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
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(path, nil, nil, nil);
        }
    }];
#else
    [_writer finishWritingWithCompletionHandler: ^{}];
#endif
    _writer = NULL;
    _videoWriterInput = NULL;
    _audioWriterInput = NULL;
    _bufferAdaptor = NULL;
    _isRecording = NO;
}

}
