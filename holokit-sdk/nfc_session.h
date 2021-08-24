//
//  nfc_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/9.
//

#import <CoreNFC/CoreNFC.h>

@interface NFCSession : NSObject

@property (nonatomic, assign) bool isFinished;
@property (nonatomic, assign) bool isValid;

- (void)startReaderSession;

- (void)stopReaderSession;

+ (id)sharedNFCSession;

@end
