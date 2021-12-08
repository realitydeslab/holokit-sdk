//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#import "IUnityInterface.h"
#import "ar_session.h"

typedef void (*BrowserDidFindPeer)(unsigned long clientId, const char *deviceName);
BrowserDidFindPeer BrowserDidFindPeerDelegate = NULL;

typedef void (*BrowserDidLosePeer)(unsigned long clientId);
BrowserDidLosePeer BrowserDidLosePeerDelegate = NULL;

typedef void (*PeerDidConnect)(unsigned long clientId, const char *deviceName);
PeerDidConnect PeerDidConnectDelegate = NULL;

typedef void (*PeerDidDisconnect)(unsigned long clientId);
PeerDidDisconnect PeerDidDisconnectDelegate = NULL;

typedef void (*DidReceivePeerData)(unsigned long clientId, unsigned char *data, int dataArrayLength);
DidReceivePeerData DidReceivePeerDataDelegate = NULL;

typedef void (*DidReceivePongMessage)(unsigned long clientId, double rtt);
DidReceivePongMessage DidReceivePongMessageDelegate = NULL;

typedef void (*DidDisconnectFromServer)(void);
DidDisconnectFromServer DidDisconnectFromServerDelegate = NULL;

typedef enum {
    MLAPIData,
    Ping,
    Pong,
    Disconnection
} MultipeerDataType;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *localPeerID;
@property (nonatomic, strong) MCPeerID *hostPeerID;
//@property (nonatomic, strong) MCSession *mcSession;
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *peerName2ClientIdMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *peerName2DeviceNameMap;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSString *> *peerID2ARSessionIdMap;
@property (nonatomic, strong) NSMutableArray<MCPeerID *> *browsedPeers;
@property (assign) double lastPingTime;
@property (assign) int pingCount;
@property (assign) int pongCount;

@end

@implementation MultipeerSession

- (instancetype)initWithServiceType:(NSString *)serviceType {
    self = [super init];
    if (self) {
        self.serviceType = serviceType;
        NSString *deviceName = [UIDevice currentDevice].name;
        NSString *systemUptime = [[NSNumber numberWithDouble:[[NSProcessInfo processInfo] systemUptime]] stringValue];
        NSString *displayNameBeforeHash = [NSString stringWithFormat:@"%@%@", deviceName, systemUptime];
        unsigned long hashedNumber = [displayNameBeforeHash hash];
        NSString *displayName = [NSString stringWithFormat:@"%lu", hashedNumber];
        // To prevent the overflow problem when marshalling.
        displayName = [displayName substringToIndex:11];
        NSLog(@"[mc_session]: local peer display name: %@", displayName);
        self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        
        // If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.mcSession.delegate = self;
        
        self.peerName2ClientIdMap = [[NSMutableDictionary alloc] init];
        self.browsedPeers = [[NSMutableArray alloc] init];
        self.peerName2DeviceNameMap = [[NSMutableDictionary alloc] init];
        self.peerID2ARSessionIdMap = [[NSMutableDictionary alloc] init];
        
        self.pingCount = 0;
        self.pongCount = 0;
    }
    return self;
}

- (void)sendToAllPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    if (self.mcSession.connectedPeers.count == 0) {
        NSLog(@"[mc_session]: There is no connected peer.");
        return;
    }
    bool success = [self.mcSession sendData:data toPeers:self.mcSession.connectedPeers withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session]: Failed to send data to all peers.");
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerID sendDataMode:(MCSessionSendDataMode)sendDataMode {
    NSArray *peerArray = @[peerID];
    bool success = [self.mcSession sendData:data toPeers:peerArray withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session]: Failed to send data to peer %@.", peerID.displayName);
    }
}

- (void)startBrowsing {
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.serviceType];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
}

- (void)stopBrowsing {
    [self.browser stopBrowsingForPeers];
}

- (void)startAdvertising {
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"DeviceName":[[UIDevice currentDevice] name], @"RequirePassword": @"No" };
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:discoveryInfo serviceType:self.serviceType];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
}

- (void)stopAdvertising {
    [self.advertiser stopAdvertisingPeer];
}

- (bool)isHost {
    if (self.advertiser != nil) {
        return YES;
    } else {
        return NO;
    }
}

+ (MCSessionSendDataMode)convertNetworkDelivery2SendDataMode:(int)networkDelivery {
    switch(networkDelivery) {
        case 0:
            // Unreliable
            return MCSessionSendDataUnreliable;
        case 1:
            // UnreliableSequenced
            return MCSessionSendDataUnreliable;
        case 2:
            // Reliable
            return MCSessionSendDataReliable;
        case 3:
            // ReliableSequenced
            return MCSessionSendDataReliable;
        case 4:
            // ReliableFragmentedSequenced
            return MCSessionSendDataReliable;
        default:
            return MCSessionSendDataReliable;
    }
}

+ (NSNumber *)convertNSString2NSNumber:(NSString *)str {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter numberFromString:str];
}

- (void)invitePeer:(unsigned long)clientId {
    for (MCPeerID *peerID in self.browsedPeers) {
        if (clientId == [self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            self.hostPeerID = peerID;
            NSDictionary<NSString *, NSString *> *dict = @{ @"DeviceName":[[UIDevice currentDevice] name], @"Password":@"" };
            NSData *context = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:NO error:nil];
            [self.browser invitePeer:peerID toSession:self.mcSession withContext:context timeout:30];
        }
    }
}

- (void)sendARSessionId2AllPeers {
    NSString* arSessionId = [[HoloKitARSession sharedARSession] arSession].identifier.UUIDString;
    NSLog(@"[mc_session] send my ARSessionId %@", arSessionId);
    const char *str = [arSessionId cStringUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = (unsigned char)5;
    data[1] = (unsigned char)strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
}

- (void)removeAllAnchorsOriginatingFromARSessionWithID:(NSString *)ARSessionId {
    ARSession *arSession = [[HoloKitARSession sharedARSession] arSession];
    for (ARAnchor *anchor in arSession.currentFrame.anchors) {
        NSString *anchorSessionId = anchor.sessionIdentifier.UUIDString;
        if ([anchorSessionId isEqualToString:ARSessionId]) {
            [arSession removeAnchor:anchor];
        }
    }
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    //NSDictionary<NSString *, NSString *> *dict = (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:context];
    NSDictionary<NSString *, NSString *> *dict = [NSKeyedUnarchiver unarchivedDictionaryWithKeysOfClass:[NSString class] objectsOfClass:[NSString class] fromData:context error:nil];
    NSString *deviceName = dict[@"DeviceName"];
    if (self.peerName2ClientIdMap[peerID.displayName] == nil) {
        [self.peerName2ClientIdMap setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
    }
    if (self.peerName2DeviceNameMap[peerID.displayName] == nil) {
        [self.peerName2DeviceNameMap setObject:deviceName forKey:peerID.displayName];
    }
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[mc_session] broswer found peer %@", peerID.displayName);
    NSString *deviceName = info[@"DeviceName"];
    NSNumber *clientId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
    if (self.peerName2ClientIdMap[peerID.displayName] == nil) {
        [self.peerName2ClientIdMap setObject:clientId forKey:peerID.displayName];
    }
    if (self.peerName2DeviceNameMap[peerID.displayName] == nil) {
        [self.peerName2DeviceNameMap setObject:deviceName forKey:peerID.displayName];
    }
    [self.browsedPeers addObject:peerID];
    if (BrowserDidFindPeerDelegate != NULL) {
        BrowserDidFindPeerDelegate([clientId unsignedLongValue], [deviceName UTF8String]);
    }
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    //NSLog(@"[mc_session]: browser lost a peer %@.", peerID.displayName);
    [self.browsedPeers removeObject:peerID];
    if (BrowserDidLosePeerDelegate != NULL) {
        BrowserDidLosePeerDelegate([[MultipeerSession convertNSString2NSNumber:peerID.displayName] unsignedLongValue]);
    }
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch(state) {
        case MCSessionStateConnecting:
            NSLog(@"[mc_session]: connecting with peer %@.", peerID.displayName);
            break;
        case MCSessionStateConnected:
            NSLog(@"[mc_session]: connected with peer %@.", peerID.displayName);
            if ([self isHost]) {
                //[self.connectedPeersForUnity addObject:peerID];
                //NewPeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue], [self.peerName2DeviceNameMap[peerID.displayName] UTF8String]);
            } else {
                if ([peerID isEqual:self.hostPeerID]) {
                    PeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue], [self.peerName2DeviceNameMap[peerID.displayName] UTF8String]);
                }
            }
            break;
        case MCSessionStateNotConnected:
            NSLog(@"[mc_session]: disconnected with peer %@.", peerID.displayName);
            if ([self isHost]) {
                unsigned long transportId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
                if (PeerDidDisconnectDelegate != NULL) {
                    PeerDidDisconnectDelegate(transportId);
                }
                [self removeAllAnchorsOriginatingFromARSessionWithID:self.peerID2ARSessionIdMap[peerID]];
            }
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    // First try to decode the received data as ARCollaboration data.
    ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
    if (collaborationData != nil) {
        [[HoloKitARSession sharedARSession] updateWithCollaborationData:collaborationData];
        return;
    }

    unsigned char *decodedData = (unsigned char *) [data bytes];
    if (decodedData == nil) {
        NSLog(@"[ar_session]: Failed to decode the received data.");
        return;
    }
    switch ((int)decodedData[0]) {
        case 0: {
            int dataArrayLength;
            memcpy(&dataArrayLength, decodedData + 1, sizeof(int));
            //NSLog(@"[ar_session]: did receive Netcode data with array length %d", dataArrayLength);
            unsigned char netcodeData[dataArrayLength];
            for (int i = 0; i < dataArrayLength; i++) {
                netcodeData[i] = decodedData[i + 1 + sizeof(int)];
            }
            unsigned long clientId = [self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue];
            DidReceivePeerDataDelegate(clientId, netcodeData, dataArrayLength);
            break;
        }
        case 1: {
            // Did receive a Ping data
            unsigned char pongMessageData[1];
            pongMessageData[0] = (unsigned char)2;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pongMessageData length:sizeof(pongMessageData)];
            [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataUnreliable];
            break;
        }
        case 2: {
            // Did receive a Pong message
            //NSLog(@"[mc_session]: pong time %d %f", ++self.pongTime, [[NSProcessInfo processInfo] systemUptime]);
            double rtt = ([[NSProcessInfo processInfo] systemUptime] - self.lastPingTime) * 1000;
            unsigned long clientId = [self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue];
            DidReceivePongMessageDelegate(clientId, rtt);
            break;
        }
        case 3: {
            NSLog(@"[mc_session] did receive a connection message");
//            [self.connectedPeersForUnity addObject:peerID];
//            PeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue], [self.peerName2DeviceNameMap[peerID.displayName] UTF8String]);
            break;
        }
        case 4: {
            NSLog(@"[mc_session] Did receive a disconnection message.");
            [self.mcSession disconnect];
            if (DidDisconnectFromServerDelegate != NULL) {
                DidDisconnectFromServerDelegate();
            }
            break;
        }
        case 5: {
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *arSessionId = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            NSLog(@"[mc_session] Did receive an ARSessionId %@", arSessionId);
            [self.peerID2ARSessionIdMap setObject:arSessionId forKey:peerID];
            break;
        }
        default: {
            NSLog(@"[mc_session] Failed to decode the received data.");
            break;
        }
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
 
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler {
    certificateHandler(YES);
}

@end

#pragma mark - extern "C"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCInitialize(const char* serviceType) {
    //HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    //ar_session_instance.multipeerSession = [[MultipeerSession alloc] initWithServiceType:[NSString stringWithUTF8String:serviceType]];
    [[HoloKitARSession sharedARSession] setMultipeerSession:[[MultipeerSession alloc] initWithServiceType:[NSString stringWithUTF8String:serviceType]]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStartBrowsing(void) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    [ar_session_instance.multipeerSession startBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStartAdvertising(void) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    [ar_session_instance.multipeerSession startAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStopBrowsing(void) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    [ar_session_instance.multipeerSession stopBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStopAdvertising(void) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    [ar_session_instance.multipeerSession stopAdvertising];
}

// https://stackoverflow.com/questions/3426491/how-can-you-marshal-a-byte-array-in-c
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendData(unsigned long clientId, unsigned char *data, int dataArrayLength, int networkDelivery) {
    //NSLog(@"[mc_session] send data to client Id %lu and data size %d", clientId, dataArrayLength);
    MultipeerSession *multipeerSession = [[HoloKitARSession sharedARSession] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            unsigned char structuredData[dataArrayLength + 1 + sizeof(int)];
            // Append the data type at the beginning of the array
            structuredData[0] = (unsigned char)0;
            // Append the length of the data array at the second place
            //structuredData[1] = (unsigned char)dataArrayLength;
            memcpy(structuredData + 1, &dataArrayLength, sizeof(int));
            // TODO: is there a better way to do this? I mean copying array
            for (int i = 0; i < dataArrayLength; i++) {
                structuredData[i + 1 + sizeof(int)] = data[i];
            }

            // Convert the data to NSData format
            // https://stackoverflow.com/questions/8354881/convert-unsigned-char-array-to-nsdata-and-back
            NSData *dataReadyToBeSent = [NSData dataWithBytes:structuredData length:sizeof(structuredData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:[MultipeerSession convertNetworkDelivery2SendDataMode:networkDelivery]];
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendPingMessage(unsigned long clientId) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeerSession = ar_session_instance.multipeerSession;
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            // Prepare the Ping message
            unsigned char pingMessageData[1];
            pingMessageData[0] = (unsigned char)1;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pingMessageData length:sizeof(pingMessageData)];
            multipeerSession.lastPingTime = [[NSProcessInfo processInfo] systemUptime];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataUnreliable];
            //NSLog(@"[mc_session]: ping time %d %f", ++multipeerSession.pingTime, [[NSProcessInfo processInfo] systemUptime]);
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectLocalClient(void) {
    [[[[HoloKitARSession sharedARSession] multipeerSession] mcSession] disconnect];
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectRemoteClient(unsigned long clientId) {
    MultipeerSession *multipeerSession = [[HoloKitARSession sharedARSession] multipeerSession];
    if (![multipeerSession isHost]) {
        return;
    }
    
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            // Prepare the disconnection message
            unsigned char disconnectionData[1];
            disconnectionData[0] = (unsigned char)4;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
            return;
        }
    }
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectAllClients(void) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeer_session = ar_session_instance.multipeerSession;
    if (![multipeer_session isHost]) {
        return;
    }
    
    // Prepare the disconnection message
    unsigned char disconnectionData[1];
    disconnectionData[0] = (unsigned char)4;
    
    NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
    [multipeer_session sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCShutdown(void) {
    MultipeerSession *multipeerSession = [[HoloKitARSession sharedARSession] multipeerSession];
    if ([multipeerSession isHost]) {
        [multipeerSession.advertiser stopAdvertisingPeer];
    } else {
        [multipeerSession.browser stopBrowsingForPeers];
    }
    [multipeerSession.mcSession disconnect];
    [multipeerSession setMcSession:nil];
    multipeerSession = nil;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPeerDidConnectDelegate(PeerDidConnect callback) {
    PeerDidConnectDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetBrowserDidFindPeerDelegate(BrowserDidFindPeer callback) {
    BrowserDidFindPeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetBrowserDidLosePeerDelegate(BrowserDidLosePeer callback) {
    BrowserDidLosePeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceivePeerDataDelegate(DidReceivePeerData callback) {
    DidReceivePeerDataDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceivePongMessageDelegate(DidReceivePongMessage callback) {
    DidReceivePongMessageDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPeerDidDisconnectDelegate(PeerDidDisconnect callback) {
    PeerDidDisconnectDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidDisconnectFromServerDelegate(DidDisconnectFromServer callback) {
    DidDisconnectFromServerDelegate = callback;
}

unsigned long UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCGetServerClientId(void) {
    return [[MultipeerSession convertNSString2NSNumber:[[[HoloKitARSession sharedARSession] multipeerSession] localPeerID].displayName] unsignedLongValue];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCInvitePeer(unsigned long clientId) {
    [[[HoloKitARSession sharedARSession] multipeerSession] invitePeer:clientId];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendConnectionMessage2Client(unsigned long clientId) {
    NSLog(@"[mc_session]: send connection message to %lu", clientId);
    MultipeerSession *multipeerSession = [[HoloKitARSession sharedARSession] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            unsigned char connectionMessageData[1];
            connectionMessageData[0] = (unsigned char)3;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:connectionMessageData length:sizeof(connectionMessageData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
        }
    }
}
