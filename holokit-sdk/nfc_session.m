//
//  nfc_session.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/4/9.
//

#import "nfc_session.h"
#import "holokit_sdk-Swift.h"
#import "IUnityInterface.h"

typedef void (*NfcAuthenticationDidComplete)(bool);
NfcAuthenticationDidComplete NfcAuthenticationDidCompleteDelegate = NULL;

@interface NFCSession () <NFCTagReaderSessionDelegate>

@property (nonatomic, strong) NFCTagReaderSession* readerSession;
@property (assign) BOOL success;
@property (assign) BOOL usingNfc;

@end

@implementation NFCSession

- (instancetype)init {
    self = [super init];
    if (self) {
        self.usingNfc = true;
    }
    return self;
}

+ (id)sharedInstance {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)startReaderSessionWith:(NSString *)alertMessage {
    if (self.usingNfc) {
        self.success = NO;
        self.readerSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:nil];
        self.readerSession.alertMessage = alertMessage;
        [self.readerSession beginSession];
    }
    else {
        if (NfcAuthenticationDidCompleteDelegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NfcAuthenticationDidCompleteDelegate(YES);
            });
        }
    }
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

}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    if (NfcAuthenticationDidCompleteDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NfcAuthenticationDidCompleteDelegate(self.success);
        });
    }
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags {
    if ([tags count] > 1) {
        [session invalidateSessionWithErrorMessage:@"More than one NFC tags were detected."];
        return;
    }
    id<NFCTag> tag = tags[0];
    [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            [session invalidateSessionWithErrorMessage:@"Failed to connect to the NFC tag."];
            return;
        }
        id<NFCISO7816Tag> sTag = [tag asNFCISO7816Tag];
        if (sTag == nil) {
            [session invalidateSessionWithErrorMessage:@"This tag is not compliant to ISO7816"];
            return;
        }
        NSString *uid = [NFCSession stringWithDeviceToken:[sTag identifier]];
        uid = [uid uppercaseString];
        uid = [NSString stringWithFormat:@"%@%@", @"0x", uid];
        NSLog(@"[nfc_session] tag uid %@", uid);
        [sTag queryNDEFStatusWithCompletionHandler:^(NFCNDEFStatus status, NSUInteger capacity, NSError * _Nullable error) {
            if (error != nil) {
                [session invalidateSessionWithErrorMessage:@"Failed to query NDEF status of the tag"];
                return;
            }
            switch (status) {
                case NFCNDEFStatusNotSupported: {
                    [session invalidateSessionWithErrorMessage:@"NDEF is not supported on this tag"];
                    return;
                }
                case NFCNDEFStatusReadOnly: {
                    [session invalidateSessionWithErrorMessage:@"This tag is read only"];
                    return;
                }
                case NFCNDEFStatusReadWrite: {
                    [sTag readNDEFWithCompletionHandler:^(NFCNDEFMessage * _Nullable message, NSError * _Nullable error) {
                        if ([message.records count] < 1 || message.records[0].payload == nil) {
                            [session invalidateSessionWithErrorMessage:@"There is no data in this tag"];
                            return;
                        }
                        NSString *rawContent = [[NSString alloc] initWithData:message.records[0].payload encoding:NSUTF8StringEncoding];
                        NSLog(@"[nfc_session] raw content %@", rawContent);
                        NSString *signature = [NFCSession findSignatureFromRawContent:rawContent];
                        NSLog(@"[nfc_session] signature %@", signature);
                        NSString *content = [NFCSession findContentFromRawContent:rawContent];
                        NSLog(@"[nfc_session] content %@", content);
                        if ([content isEqualToString:uid]) {
                            if ([Crypto validateSignatureWithSignature:signature content:content]) {
                                self.success = YES;
                                [session setAlertMessage:@"NFC authentication succeeded"];
                                [session invalidateSession];
                                return;
                            } else {
                                [session invalidateSessionWithErrorMessage:@"NFC authentication failed"];
                                return;
                            }
                        } else {
                            [session invalidateSessionWithErrorMessage:@"NFC authentication failed"];
                            return;
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

#pragma mark - extern "C"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_StartNfcAuthentication(const char *alertMessage) {
    if (alertMessage == NULL) {
        [[NFCSession sharedInstance] startReaderSessionWith:nil];
    } else {
        [[NFCSession sharedInstance] startReaderSessionWith:[NSString stringWithUTF8String:alertMessage]];
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetNfcAuthenticationDidCompleteDelegate(NfcAuthenticationDidComplete callback) {
    NfcAuthenticationDidCompleteDelegate = callback;
}

void UnityHoloKit_SetUsingNfc(bool value) {
    [[NFCSession sharedInstance] setUsingNfc:value];
}
