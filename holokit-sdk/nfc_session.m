//
//  nfc_session.m
//  holokit-sdk-skeleton
//
//  Created by Yuchen on 2021/4/9.
//

#import <Foundation/Foundation.h>
#import "nfc_session.h"

@interface NFCSession () <NFCNDEFReaderSessionDelegate>

@end

@implementation NFCSession

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

+ (id) sharedNFCSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void) startReaderSession {
    NFCNDEFReaderSession* readerSession = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:nil invalidateAfterFirstRead:YES];
    readerSession.alertMessage = @"HoloKit needs your NFC";
    [readerSession beginSession];
}

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {
    NSLog(@"didDetectNDEFs.");
    // TODO: do something useful
    NSArray<NFCNDEFPayload *> *records = messages[0].records;
    NSLog(@"num of records: %d", records.count);
    for(NFCNDEFPayload *record in records) {
        NSLog(@"identifier %x", record.identifier);
        NSLog(@"payload %x", record.payload);
        NSLog(@"type %x", record.type);
        NSLog(@"typeNameFormat %x", record.typeNameFormat);
    }
}

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
}

@end
