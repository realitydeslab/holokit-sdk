//
//  speech_recognizer.h
//  holokit
//
//  Created by Yuchen on 2021/8/12.
//

#import <Speech/Speech.h>

@interface HoloKitSpeechRecognizer: NSObject

@property(nonatomic, assign) BOOL isReadyToRecord;

- (void)startRecording;
- (void)stopRecording;

@end
