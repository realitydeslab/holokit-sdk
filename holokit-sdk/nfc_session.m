//
//  nfc_session.m
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/9.
//

#import <Foundation/Foundation.h>
#import "nfc_session.h"

@interface NFCSession () <NFCNDEFReaderSessionDelegate>

@property (nonatomic, strong) NFCNDEFReaderSession* readerSession;

@end

@implementation NFCSession

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isFinished = NO;
        self.isValid = NO;
    }
    return self;
}

+ (id)sharedNFCSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)startReaderSession {
    self.readerSession = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:nil invalidateAfterFirstRead:YES];
    self.readerSession.alertMessage = @"Please put your iPhone onto the HoloKit to enter that Reality.";
    [self.readerSession beginSession];
    NSLog(@"[nfc_session]: NFC verification started.");
}

- (void)stopReaderSession {
    [self.readerSession invalidateSession];
    self.readerSession = nil;
}

#pragma mark - Delegates

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {
    NFCNDEFPayload* payload = messages[0].records[0];
    NSString* nfcUrl = [[NSString alloc] initWithData:payload.payload encoding:NSUTF8StringEncoding];
    if (nfcUrl == NULL) {
        NSLog(@"[nfc_session]: failed to interpret nfc url.");
        return;
    }
    NSLog(@"[nfc_session]: %@", nfcUrl);
    // TODO: validate the url
    self.isValid = YES;
}

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
    //NSLog(@"[nfc_session]: did invalidate with error");
    self.isFinished = YES;
}

- (void)readerSessionDidBecomeActive:(NFCNDEFReaderSession *)session {
    //NSLog(@"[nfc_session]: did become active");
    self.isFinished = NO;
    self.isValid = NO;
}

@end
