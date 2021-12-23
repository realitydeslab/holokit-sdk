//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#import "IUnityInterface.h"
#import "ar_session_manager.h"

typedef void (*BrowserDidFindPeer)(unsigned long transportId, const char *deviceName);
BrowserDidFindPeer BrowserDidFindPeerDelegate = NULL;

typedef void (*BrowserDidLosePeer)(unsigned long transportId);
BrowserDidLosePeer BrowserDidLosePeerDelegate = NULL;

typedef void (*PeerDidConnect)(unsigned long transportId, const char *deviceName);
PeerDidConnect PeerDidConnectDelegate = NULL;

typedef void (*PeerDidDisconnect)(unsigned long transportId);
PeerDidDisconnect PeerDidDisconnectDelegate = NULL;

typedef void (*DidReceivePeerData)(unsigned long transportId, unsigned char *data, int dataArrayLength);
DidReceivePeerData DidReceivePeerDataDelegate = NULL;

typedef void (*DidReceivePongMessage)(unsigned long transportId, double rtt);
DidReceivePongMessage DidReceivePongMessageDelegate = NULL;

typedef void (*DidDisconnectFromServer)(void);
DidDisconnectFromServer DidDisconnectFromServerDelegate = NULL;

typedef void (*PeerDidDisconnectTemporarily)(unsigned long transportId);
PeerDidDisconnectTemporarily PeerDidDisconnectTemporarilyDelegate = NULL;

typedef void (*PeerDidReconnect)(unsigned long transportId);
PeerDidReconnect PeerDidReconnectDelegate = NULL;

typedef void (*DidReceiveARWorldMap)(void);
DidReceiveARWorldMap DidReceiveARWorldMapDelegate = NULL;

typedef void (*DidReceiveHostLocalIpAddress)(const char *ip);
DidReceiveHostLocalIpAddress DidReceiveHostLocalIpAddressDelegate = NULL;

typedef void (*DidReceivePhotonRoomName)(const char *roomName);
DidReceivePhotonRoomName DidReceivePhotonRoomNameDelegate = NULL;

typedef enum {
    NetcodeTransportUNet = 0,
    NetcodeTransportMPC = 1,
    NetcodeTransportPhoton = 2
} NetcodeTransport;

typedef enum {
    ARSyncModeNone = 0,
    ARSyncModeCollaboration = 1,
    ARSyncModeWorldMap = 2
} ARSyncMode;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *localPeerID;
@property (nonatomic, strong) MCPeerID *hostPeerID;
//@property (nonatomic, strong) MCSession *mcSession;
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSNumber *> *peerID2TransportIdMap;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSString *> *peerID2DeviceNameMap;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSString *> *peerID2ARSessionIdMap;
@property (nonatomic, strong) NSMutableArray<MCPeerID *> *browsedPeers;
@property (assign) bool isInAR;
@property (assign) bool isReconnecting;
@property (assign) NetcodeTransport netcodeTransport;
@property (nonatomic, strong) NSString *hostLocalIpAddress;
@property (nonatomic, strong) NSString *photonRoomName;
@property (assign) ARSyncMode arSyncMode;

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
        // To prevent the overflow problem when marshalling although it is unlikely to happen.
        displayName = [displayName substringToIndex:11];
        NSLog(@"[mc_session]: local peer display name: %@", displayName);
        self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        
        // If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.mcSession.delegate = self;
        
        self.peerID2TransportIdMap = [[NSMutableDictionary alloc] init];
        self.browsedPeers = [[NSMutableArray alloc] init];
        self.peerID2DeviceNameMap = [[NSMutableDictionary alloc] init];
        self.peerID2ARSessionIdMap = [[NSMutableDictionary alloc] init];
        
        self.isInAR = NO;
        self.isReconnecting = NO;
    }
    return self;
}

- (void)sendToAllPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    bool success = [self.mcSession sendData:data toPeers:self.mcSession.connectedPeers withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session] Failed to send data to all peers");
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerID sendDataMode:(MCSessionSendDataMode)sendDataMode {
    NSArray *peerArray = @[peerID];
    bool success = [self.mcSession sendData:data toPeers:peerArray withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session] Failed to send data to peer %@", peerID.displayName);
    }
}

- (void)startBrowsing {
    self.browsedPeers = [[NSMutableArray alloc] init];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.serviceType];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
    NSLog(@"[mc_session] did start browsing");
}

- (void)stopBrowsing {
    [self.browser stopBrowsingForPeers];
    self.browsedPeers = [[NSMutableArray alloc] init];
    NSLog(@"[mc_session] did stop browsing");
}

- (void)startAdvertising {
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"DeviceName":[[UIDevice currentDevice] name], @"RequirePassword": @"No" };
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:discoveryInfo serviceType:self.serviceType];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    NSLog(@"[mc_session] did start Advertising");
}

- (void)stopAdvertising {
    [self.advertiser stopAdvertisingPeer];
    NSLog(@"[mc_session] did stop advertising");
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

- (void)invitePeer:(MCPeerID *)peerID {
    NSDictionary<NSString *, NSString *> *dict = @{ @"DeviceName":[[UIDevice currentDevice] name], @"Password":@"" };
    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:NO error:nil];
    [self.browser invitePeer:peerID toSession:self.mcSession withContext:context timeout:30];
}

- (void)sendARSessionId2AllPeers {
    NSString* arSessionId = [[ARSessionManager sharedARSessionManager] arSession].identifier.UUIDString;
    const char *str = [arSessionId cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 5;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
}

- (void)sendHostLocalIpAddress2Peer:(MCPeerID *)peerID {
    const char *str = [self.hostLocalIpAddress cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 7;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
}

- (void)sendPhotonRoomName2Peer:(MCPeerID *)peerID {
    const char *str = [self.photonRoomName cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 8;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
}

- (void)removeAllAnchorsOriginatingFromARSessionWithID:(NSString *)ARSessionId {
    ARSession *arSession = [[ARSessionManager sharedARSessionManager] arSession];
    for (ARAnchor *anchor in arSession.currentFrame.anchors) {
        NSString *anchorSessionId = anchor.sessionIdentifier.UUIDString;
        if ([anchorSessionId isEqualToString:ARSessionId]) {
            [arSession removeAnchor:anchor];
        }
    }
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"[mc_session] did receive invitation from peer %@", [peerID displayName]);
    NSDictionary<NSString *, NSString *> *dict = [NSKeyedUnarchiver unarchivedDictionaryWithKeysOfClass:[NSString class] objectsOfClass:[NSString class] fromData:context error:nil];
    NSString *deviceName = dict[@"DeviceName"];
    [self.peerID2TransportIdMap setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID];
    [self.peerID2DeviceNameMap setObject:deviceName forKey:peerID];
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[mc_session] broswer found peer %@", peerID.displayName);
    if (self.isReconnecting && self.hostPeerID) {
        [self invitePeer:peerID];
        return;
    }
    
    NSString *deviceName = info[@"DeviceName"];
    NSNumber *transportId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
    [self.peerID2TransportIdMap setObject:transportId forKey:peerID];
    [self.peerID2DeviceNameMap setObject:deviceName forKey:peerID];
    [self.browsedPeers addObject:peerID];
    if (BrowserDidFindPeerDelegate != NULL) {
        BrowserDidFindPeerDelegate([transportId unsignedLongValue], [deviceName UTF8String]);
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
            NSLog(@"[mc_session] connecting with peer %@.", peerID.displayName);
            break;
        case MCSessionStateConnected:
            NSLog(@"[mc_session] connected with peer %@.", peerID.displayName);
            if ([self isHost]) {
                switch(self.netcodeTransport) {
                    case NetcodeTransportUNet:
                        [self sendHostLocalIpAddress2Peer:peerID];
                        break;
                    case NetcodeTransportMPC:
                        
                        break;
                    case NetcodeTransportPhoton:
                        [self sendPhotonRoomName2Peer:peerID];
                        break;
                }
            } else {
                [self stopBrowsing];
            }
            
            // For reconnection
//            if (self.isInAR) {
//                if ([self isHost]) {
//                    if (PeerDidReconnectDelegate != NULL) {
//                        PeerDidReconnectDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
//                    }
//                } else {
//                    if (PeerDidReconnectDelegate != NULL) {
//                        PeerDidReconnectDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
//                    }
//                }
//            } else {
//                if ([self isHost]) {
//
//                } else {
//                    if ([peerID isEqual:self.hostPeerID]) {
//                        PeerDidConnectDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue], [self.peerID2DeviceNameMap[peerID] UTF8String]);
//                    }
//                }
//            }
            
            break;
        case MCSessionStateNotConnected:
            NSLog(@"[mc_session] disconnected with peer %@.", peerID.displayName);
//            if (self.isInAR) {
//                if ([self isHost]) {
//                    // Peer temporarily disconnected.
//                    if (PeerDidDisconnectTemporarilyDelegate != NULL) {
//                        PeerDidDisconnectTemporarilyDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
//                    }
//                } else {
//                    if ([peerID isEqual:self.hostPeerID]) {
//                        NSLog(@"[mc_session] disconnected from the host");
//                        if (PeerDidDisconnectTemporarilyDelegate != NULL) {
//                            PeerDidDisconnectTemporarilyDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
//                        }
//                        // Try to reconnect.
//                        self.isReconnecting = YES;
//                        [self startBrowsing];
//                    }
//                }
//            } else {
//                if ([self isHost]) {
//                    unsigned long transportId = [self.peerID2TransportIdMap[peerID] unsignedLongValue];
//                    if (PeerDidDisconnectDelegate != NULL) {
//                        PeerDidDisconnectDelegate(transportId);
//                    }
//                    //[self removeAllAnchorsOriginatingFromARSessionWithID:self.peerID2ARSessionIdMap[peerID]];
//                } else {
//
//                }
//            }
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    unsigned char *decodedData = (unsigned char *) [data bytes];
    switch ((int)decodedData[0]) {
        case 0: {
            int dataArrayLength;
            memcpy(&dataArrayLength, decodedData + 1, sizeof(int));
            //NSLog(@"[ar_session]: did receive Netcode data with array length %d", dataArrayLength);
            unsigned char netcodeData[dataArrayLength];
            for (int i = 0; i < dataArrayLength; i++) {
                netcodeData[i] = decodedData[i + 1 + sizeof(int)];
            }
            unsigned long transportId = [self.peerID2TransportIdMap[peerID] unsignedLongValue];
            DidReceivePeerDataDelegate(transportId, netcodeData, dataArrayLength);
            break;
        }
//        case 1: {
//            // Did receive a Ping data
//            unsigned char pongMessageData[1];
//            pongMessageData[0] = (unsigned char)2;
//            NSData *dataReadyToBeSent = [NSData dataWithBytes:pongMessageData length:sizeof(pongMessageData)];
//            [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataUnreliable];
//            break;
//        }
//        case 2: {
//            // Did receive a Pong message
//            //NSLog(@"[mc_session]: pong time %d %f", ++self.pongTime, [[NSProcessInfo processInfo] systemUptime]);
//            double rtt = ([[NSProcessInfo processInfo] systemUptime] - self.lastPingTime) * 1000;
//            unsigned long transportId = [self.peerID2TransportIdMap[peerID] unsignedLongValue];
//            DidReceivePongMessageDelegate(transportId, rtt);
//            break;
//        }
//        case 3: {
//            NSLog(@"[mc_session] did receive a connection message");
////            [self.connectedPeersForUnity addObject:peerID];
////            PeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue], [self.peerName2DeviceNameMap[peerID.displayName] UTF8String]);
//            break;
//        }
//        case 4: {
//            NSLog(@"[mc_session] Did receive a disconnection message");
//            [self.mcSession disconnect];
//            if (DidDisconnectFromServerDelegate != NULL) {
//                DidDisconnectFromServerDelegate();
//            }
//            break;
//        }
//        case 5: {
//            // ARSessionId
//            int strlen = (int)decodedData[1];
//            char *str = malloc(strlen);
//            memcpy(str, decodedData + 2, strlen);
//            NSString *arSessionId = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
//            //NSLog(@"[mc_session] Did receive an ARSessionId %@", arSessionId);
//            [self.peerID2ARSessionIdMap setObject:arSessionId forKey:peerID];
//            break;
//        }
//        case 6: {
//            // Did reset ARSession message
//            NSLog(@"[mc_session] did receive DidResetARSession message");
//            NSString *arSessionId = self.peerID2ARSessionIdMap[peerID];
//            ARSession *arSession = [[ARSessionManager sharedARSessionManager] arSession];
//            for (ARAnchor *anchor in [[arSession currentFrame] anchors]) {
//                if ([anchor.identifier.UUIDString isEqualToString:arSessionId]) {
//                    [arSession removeAnchor:anchor];
//                }
//            }
//            break;
//        }
        case 7: {
            // Host local ip address
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *hostLocalIpAddress = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            DidReceiveHostLocalIpAddressDelegate([hostLocalIpAddress UTF8String]);
            break;
        }
        case 8: {
            // Photon room name
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *photonRoomName = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            DidReceivePhotonRoomNameDelegate([photonRoomName UTF8String]);
            break;
        }
        default: {
            if (self.arSyncMode == ARSyncModeCollaboration) {
                ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
                if (collaborationData != nil) {
                    [[ARSessionManager sharedARSessionManager] updateWithCollaborationData:collaborationData];
                    return;
                }
            } else if (self.arSyncMode == ARSyncModeWorldMap) {
                ARWorldMap *worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:data error:nil];
                if (worldMap != nil) {
                    NSLog(@"[world_map] did receive ARWorldMap with size %f kb", data.length / 1024.0);
                    ARSession *arSession = [[ARSessionManager sharedARSessionManager] arSession];
                    ARWorldTrackingConfiguration *configuration = (ARWorldTrackingConfiguration *)arSession.configuration;
                    configuration.initialWorldMap = worldMap;
                    [arSession runWithConfiguration:configuration options:ARSessionRunOptionResetTracking|ARSessionRunOptionRemoveExistingAnchors];
                    if (DidReceiveARWorldMapDelegate != NULL) {
                        DidReceiveARWorldMapDelegate();
                    }
                    return;
                }
            }
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
UnityHoloKit_MCInit(const char* serviceType) {
    [[ARSessionManager sharedARSessionManager] setMultipeerSession:[[MultipeerSession alloc] initWithServiceType:[NSString stringWithUTF8String:serviceType]]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStartBrowsing(void) {
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
    [ar_session_instance.multipeerSession startBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStartAdvertising(void) {
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
    [ar_session_instance.multipeerSession startAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStopBrowsing(void) {
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
    [ar_session_instance.multipeerSession stopBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCStopAdvertising(void) {
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
    [ar_session_instance.multipeerSession stopAdvertising];
}

// https://stackoverflow.com/questions/3426491/how-can-you-marshal-a-byte-array-in-c
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendData(unsigned long transportId, unsigned char *data, int dataArrayLength, int networkDelivery) {
    //NSLog(@"[mc_session] send data to client Id %lu and data size %d", clientId, dataArrayLength);
    MultipeerSession *multipeerSession = [[ARSessionManager sharedARSessionManager] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (transportId == [multipeerSession.peerID2TransportIdMap[peerID] unsignedLongValue]) {
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
UnityHoloKit_MCSendPingMessage(unsigned long transportId) {
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
    MultipeerSession *multipeerSession = ar_session_instance.multipeerSession;
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (transportId == [multipeerSession.peerID2TransportIdMap[peerID] unsignedLongValue]) {
            // Prepare the Ping message
            unsigned char pingMessageData[1];
            pingMessageData[0] = (unsigned char)1;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pingMessageData length:sizeof(pingMessageData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataUnreliable];
            //NSLog(@"[mc_session]: ping time %d %f", ++multipeerSession.pingTime, [[NSProcessInfo processInfo] systemUptime]);
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectLocalClient(void) {
    [[[[ARSessionManager sharedARSessionManager] multipeerSession] mcSession] disconnect];
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectRemoteClient(unsigned long transportId) {
    MultipeerSession *multipeerSession = [[ARSessionManager sharedARSessionManager] multipeerSession];
    if (![multipeerSession isHost]) {
        return;
    }
    
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (transportId == [multipeerSession.peerID2TransportIdMap[peerID] unsignedLongValue]) {
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
    ARSessionManager* ar_session_instance = [ARSessionManager sharedARSessionManager];
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
    MultipeerSession *multipeerSession = [[ARSessionManager sharedARSessionManager] multipeerSession];
    [multipeerSession.mcSession disconnect];
    [multipeerSession setMcSession:nil];
    [[ARSessionManager sharedARSessionManager] setMultipeerSession:nil];
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
    return [[MultipeerSession convertNSString2NSNumber:[[[ARSessionManager sharedARSessionManager] multipeerSession] localPeerID].displayName] unsignedLongValue];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCInvitePeer(unsigned long transportId) {
    MultipeerSession *multipeerSession = [[ARSessionManager sharedARSessionManager] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.browsedPeers) {
        if (transportId == [multipeerSession.peerID2TransportIdMap[peerID] unsignedLongValue]) {
            [multipeerSession invitePeer:peerID];
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendConnectionMessage2Client(unsigned long transportId) {
    NSLog(@"[mc_session]: send connection message to %lu", transportId);
    MultipeerSession *multipeerSession = [[ARSessionManager sharedARSessionManager] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.mcSession.connectedPeers) {
        if (transportId == [multipeerSession.peerID2TransportIdMap[peerID] unsignedLongValue]) {
            unsigned char connectionMessageData[1];
            connectionMessageData[0] = (unsigned char)3;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:connectionMessageData length:sizeof(connectionMessageData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetIsInAR(bool value) {
    [[[ARSessionManager sharedARSessionManager] multipeerSession]setIsInAR:value];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPeerDidDisconnectTemporarilyDelegate(PeerDidDisconnectTemporarily callback) {
    PeerDidDisconnectTemporarilyDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPeerDidReconnectDelegate(PeerDidReconnect callback) {
    PeerDidReconnectDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SendDidResetARSessionMessage(void) {
    unsigned char message[1];
    message[0] = (unsigned char)6;
    NSData *dataReadyToBeSent = [NSData dataWithBytes:message length:sizeof(message)];
    [[[ARSessionManager sharedARSessionManager] multipeerSession] sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveARWorldMapDelegate(DidReceiveARWorldMap callback) {
    DidReceiveARWorldMapDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetHostLocalIpAddress(const char *ip) {
    NSLog(@"[mc_session] UnityHoloKit_SetHostLocalIpAddress %@", [NSString stringWithUTF8String:ip]);
    [[[ARSessionManager sharedARSessionManager] multipeerSession] setHostLocalIpAddress:[NSString stringWithUTF8String:ip]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPhotonRoomName(const char *roomName) {
    [[[ARSessionManager sharedARSessionManager] multipeerSession] setPhotonRoomName:[NSString stringWithUTF8String:roomName]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveHostLocalIpAddressDelegate(DidReceiveHostLocalIpAddress callback) {
    DidReceiveHostLocalIpAddressDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceivePhotonRoomNameDelegate(DidReceivePhotonRoomName callback) {
    DidReceivePhotonRoomNameDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetNetcodeTransport(int transport) {
    [[[ARSessionManager sharedARSessionManager] multipeerSession] setNetcodeTransport:(NetcodeTransport)transport];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetARSyncMode(int syncMode) {
    [[[ARSessionManager sharedARSessionManager] multipeerSession] setArSyncMode:(ARSyncMode)syncMode];
}
