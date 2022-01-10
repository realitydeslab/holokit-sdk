//
//  nfc_session.h
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/9.
//

#import <CoreNFC/CoreNFC.h>

@interface NFCSession : NSObject

- (void)startReaderSession;

- (void)stopReaderSession;

+ (id)sharedNFCSession;

@end
