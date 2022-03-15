//
//  nfc_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/9.
//

#import <CoreNFC/CoreNFC.h>

@interface NFCSession : NSObject

// Set this to false to turn off nfc authentication.
// This is for testing purpose.
@property (assign) BOOL isUsingNfc;

- (void)startReaderSession;

- (void)stopReaderSession;

+ (id)sharedNFCSession;

@end
