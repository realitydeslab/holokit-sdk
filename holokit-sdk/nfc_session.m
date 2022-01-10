//
//  nfc_session.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/4/9.
//

#import "nfc_session.h"
#import "holokit_sdk-Swift.h"

@interface NFCSession () <NFCTagReaderSessionDelegate>

@property (nonatomic, strong) NFCTagReaderSession* readerSession;

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
    self.readerSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:nil];
    self.readerSession.alertMessage = @"Please put your iPhone onto HoloKit.";
    [self.readerSession beginSession];
    NSLog(@"[nfc_session] NFC authentication started...zzz");
}

- (void)stopReaderSession {
    [self.readerSession invalidateSession];
    self.readerSession = nil;
}

// https://stackoverflow.com/questions/9372815/how-can-i-convert-my-device-token-nsdata-into-an-nsstring
+ (NSString *)stringWithDeviceToken:(NSData *)deviceToken {
    const char *data = [deviceToken bytes];
    NSMutableString *token = [NSMutableString string];

    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [token appendFormat:@"%02.2hhx", data[i]];
    }

    return [token copy];
}

+ (NSString *)findSignatureFromRawContent:(NSString *)rawContent {
    NSString *a = [rawContent componentsSeparatedByString:@"s="][1];
    NSString *b = [a componentsSeparatedByString:@"&"][0];
    return b;
}

+ (NSString *)findContentFromRawContent:(NSString *)rawContent {
    NSString *a = [rawContent componentsSeparatedByString:@"c="][1];
    return a;
}

#pragma mark - Delegates

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {
    self.isFinished = NO;
    self.isValid = NO;
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    self.isFinished = YES;
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags {
    if ([tags count] > 1) {
        NSLog(@"[nfc_session] did detect more than 1 tag");
        [session invalidateSession];
    }
    id<NFCTag> tag = tags[0];
    [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            [session invalidateSessionWithErrorMessage:@"[nfc_session] failed to connect to tag"];
        }
        id<NFCISO7816Tag> sTag = [tag asNFCISO7816Tag];
        NSString *uid = [NFCSession stringWithDeviceToken:[sTag identifier]];
        NSLog(@"[nfc_session] tag uid %@", uid);
        
        [sTag queryNDEFStatusWithCompletionHandler:^(NFCNDEFStatus status, NSUInteger capacity, NSError * _Nullable error) {
            if (error != nil) {
                [session setAlertMessage:@"Failed to query the NDEF status of the tag"];
                [session invalidateSession];
                return;
            }
            switch (status) {
                case NFCNDEFStatusNotSupported: {
                    [session setAlertMessage:@"This tag does not support NDEF"];
                    [session invalidateSession];
                    break;
                }
                case NFCNDEFStatusReadOnly: {
                    [session setAlertMessage:@"This tag is read only"];
                    [session invalidateSession];
                    break;
                }
                case NFCNDEFStatusReadWrite: {
                    [sTag readNDEFWithCompletionHandler:^(NFCNDEFMessage * _Nullable message, NSError * _Nullable error) {
                        if ([message.records count] < 1 || message.records[0].payload == nil) {
                            [session setAlertMessage:@"There is no data in this tag"];
                            [session invalidateSession];
                        }
                        NSString *rawContent = [[NSString alloc] initWithData:message.records[0].payload encoding:NSUTF8StringEncoding];
                        NSLog(@"[nfc_session] raw content %@", rawContent);
                        NSString *signature = [NFCSession findSignatureFromRawContent:rawContent];
                        NSLog(@"[nfc_session] signature %@", signature);
                        NSString *content = [NFCSession findContentFromRawContent:rawContent];
                        NSLog(@"[nfc_session] content %@", content);
                        if ([content isEqualToString:uid]) {
                            if ([Crypto validateSignatureWithSignature:signature content:content]) {
                                
                            } else {
                                [session setAlertMessage:@"NFC authentication failed"];
                                [session invalidateSession];
                            }
                        } else {
                            [session setAlertMessage:@"NFC authentication failed"];
                            [session invalidateSession];
                        }
                    }];
                    break;
                }
                default: {
                    
                    break;
                }
            }
        }];
    }];
}

@end
