//
//  speech_recognizer.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/8/12.
//

#import "speech_recognizer.h"

@interface HoloKitSpeechRecognizer() <SFSpeechRecognizerDelegate>

@property(nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property(nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property(nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property(nonatomic, strong) AVAudioEngine *audioEngine;

@end

@implementation HoloKitSpeechRecognizer

- (instancetype)init {
    if (self = [super init]) {
        self.isReadyToRecord = NO;
        
        // Change language here: zh_CN, en-US, en-GB
        NSLocale *locale = [[NSLocale alloc]initWithLocaleIdentifier:@"en-GB"];
        self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        self.speechRecognizer.delegate = self;
        
        self.audioEngine = [[AVAudioEngine alloc] init];
        
        // Request authorization
        void (^handler)(SFSpeechRecognizerAuthorizationStatus) = ^void(SFSpeechRecognizerAuthorizationStatus status) {
            NSLog(@"[speech_recognizer]: SFSpeechRecognizer authorization status:");
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized: {
                    NSLog(@"[speech_recognizer]: User authorized");
                    self.isReadyToRecord = YES;
                    break;
                }
                case SFSpeechRecognizerAuthorizationStatusDenied: {
                    NSLog(@"[speech_recognizer]: User denied access to speech recognition");
                    self.isReadyToRecord = NO;
                    break;
                }
                case SFSpeechRecognizerAuthorizationStatusRestricted: {
                    NSLog(@"[speech_recognizer]: Speech recognition restricted on this device");
                    self.isReadyToRecord = NO;
                    break;
                }
                case SFSpeechRecognizerAuthorizationStatusNotDetermined: {
                    NSLog(@"[speech_recognizer]: Speech recognition not yet authorized");
                    self.isReadyToRecord = NO;
                    break;
                }
                default: {
                    self.isReadyToRecord = NO;
                    break;
                }
            }
        };
        [SFSpeechRecognizer requestAuthorization:handler];
    }
    return self;
}

- (void)startRecording {
    // Cancel the previous task if it's running.
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    
    // Configure the audio session for the app.
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionDuckOthers
                        error:nil];
    [audioSession setActive:YES
                withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                      error:nil];
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    
    // Create and configure the speech recognition request.
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if (self.recognitionRequest == nil) {
        NSLog(@"[speech_recognizer]: Unable to create a SFSpeechAudioBufferRecognitionRequest object");
        return;
    }
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    // Keep speech recognition data on device
    if (@available(ios 13, *)) {
        self.recognitionRequest.requiresOnDeviceRecognition = NO;
    }
    
    // Create a recognition task for the speech recognition session.
    // Keep a reference to the task so that it can be canceled.
    void (^resultHandler)(SFSpeechRecognitionResult *, NSError *) = ^void(SFSpeechRecognitionResult *result, NSError *error) {
        bool isFinal = NO;
        
        if (result != nil) {
            NSString *text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
            
            // TODO: Check if it hits the keyword
            
            NSLog(@"[speech_recognizer]: %@", text);
        }
        
        if (error != nil || isFinal) {
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            self.isReadyToRecord = YES;
        }
    };
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest
                                                               resultHandler:resultHandler];
    
    // Configure the microphone input.
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    void (^tapBlock)(AVAudioPCMBuffer *, AVAudioTime *) = ^void(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    };
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:tapBlock];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:nil];
}

- (void)stopRecording {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        self.isReadyToRecord = NO;
    }
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    if (available) {
        self.isReadyToRecord = YES;
        NSLog(@"[speech_recognizer]: speech recognition is available");
    } else {
        self.isReadyToRecord = NO;
        NSLog(@"[speech_recognizer]: speech recognition is not available");
    }
}

@end
