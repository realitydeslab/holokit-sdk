//
//  nfc_session.m
//  holokit-sdk
//
//  Created by Yuchen on 2021/4/9.
//

#import "nfc_session.h"
#import "holokit_sdk-Swift.h"
#import "IUnityInterface.h"
#import "ar_session.h"

typedef void (*NFCAuthenticationDidSucceed)(void);
NFCAuthenticationDidSucceed NFCAuthenticationDidSucceedDelegate = NULL;

@interface NFCSession () <NFCTagReaderSessionDelegate>

@property (nonatomic, strong) NFCTagReaderSession* readerSession;

@end

@implementation NFCSession

- (instancetype)init {
    self = [super init];
    if (self) {

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
    NSLog(@"[nfc_session] NFC authentication started...");
    self.readerSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:nil];
    self.readerSession.alertMessage = @"Please put your iPhone onto HoloKit.";
    [self.readerSession beginSession];
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

}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags {
    if ([tags count] > 1) {
        [session invalidateSessionWithErrorMessage:@"More than 1 NFC tag was detected"];
    }
    id<NFCTag> tag = tags[0];
    [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            [session invalidateSessionWithErrorMessage:@"Failed to connect to tag"];
            return;
        }
        id<NFCISO7816Tag> sTag = [tag asNFCISO7816Tag];
        NSString *uid = [NFCSession stringWithDeviceToken:[sTag identifier]];
        NSLog(@"[nfc_session] tag uid %@", uid);
        
        [sTag queryNDEFStatusWithCompletionHandler:^(NFCNDEFStatus status, NSUInteger capacity, NSError * _Nullable error) {
            if (error != nil) {
                [session invalidateSessionWithErrorMessage:@"Failed to query NDEF status of the tag"];
                return;
            }
            switch (status) {
                case NFCNDEFStatusNotSupported: {
                    [session invalidateSessionWithErrorMessage:@"NDEF is not supported on this tag"];
                    break;
                }
                case NFCNDEFStatusReadOnly: {
                    [session invalidateSessionWithErrorMessage:@"This tag is read only"];
                    break;
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
                                [session setAlertMessage:@"NFC authentication succeeded"];
                                [session invalidateSession];
                                [[ARSessionDelegateController sharedARSessionDelegateController] setIsStereoscopicRendering:YES];
                                if (NFCAuthenticationDidSucceedDelegate != NULL) {
                                    NFCAuthenticationDidSucceedDelegate();
                                }
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
UnityHoloKit_SetNFCAuthenticationDidSucceedDelegate(NFCAuthenticationDidSucceed callback) {
    NFCAuthenticationDidSucceedDelegate = callback;
}
