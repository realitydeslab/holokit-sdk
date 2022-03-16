//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#import "IUnityInterface.h"
#import "ar_session.h"

typedef void (*BrowserDidFindPeer)(unsigned long transportId, const char *deviceName);
BrowserDidFindPeer BrowserDidFindPeerDelegate = NULL;

typedef void (*BrowserDidLosePeer)(unsigned long transportId);
BrowserDidLosePeer BrowserDidLosePeerDelegate = NULL;

typedef void (*DidReceiveARWorldMap)(void);
DidReceiveARWorldMap DidReceiveARWorldMapDelegate = NULL;

typedef void (*DidReceiveHostLocalIpAddress)(const char *ip);
DidReceiveHostLocalIpAddress DidReceiveHostLocalIpAddressDelegate = NULL;

typedef void (*DidReceivePhotonRoomName)(const char *roomName);
DidReceivePhotonRoomName DidReceivePhotonRoomNameDelegate = NULL;

typedef void (*DidReceiveMPCNetcodeConnectionInvitation)(unsigned long hostTransportId);
DidReceiveMPCNetcodeConnectionInvitation DidReceiveMPCNetcodeConnectionInvitationDelegate = NULL;

typedef void (*ClientDidDisconnect)(unsigned long transportId);
ClientDidDisconnect ClientDidDisconnectDelegate = NULL;

typedef void (*DidDisconnectFromHost)(void);
DidDisconnectFromHost DidDisconnectFromHostDelegate = NULL;

typedef enum {
    NetcodeTransportUNet = 0,
    NetcodeTransportPhoton = 1,
    NetcodeTransportMPC = 2,
} NetcodeTransport;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *localPeerID;
@property (nonatomic, strong) MCPeerID *invitedPeerID;
@property (nonatomic, strong) MCPeerID *hostPeerID;
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSNumber *> *peerID2TransportIdMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, MCPeerID *> *transportId2PeerIDMap;
@property (nonatomic, strong) NSMutableDictionary<MCPeerID *, NSString *> *peerID2ARSessionIdMap;
@property (nonatomic, strong) NSMutableArray<MCPeerID *> *browsedPeers;
@property (assign) NetcodeTransport netcodeTransport;
@property (nonatomic, strong) NSString *hostLocalIpAddress;
@property (nonatomic, strong) NSString *photonRoomName;

@end

@implementation MultipeerSession

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

+ (id _Nonnull)sharedMultipeerSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)initializeWithServiceType:(NSString *)serviceType {
    self.serviceType = serviceType;
    // Hash device name and current system uptime to get a random transportId
    NSString *deviceName = [UIDevice currentDevice].name;
    NSString *systemUptime = [[NSNumber numberWithDouble:[[NSProcessInfo processInfo] systemUptime]] stringValue];
    NSString *str = [NSString stringWithFormat:@"%@%@", deviceName, systemUptime];
    unsigned long hashedNumber = [str hash];
    NSString *displayName = [NSString stringWithFormat:@"%lu", hashedNumber];
    // Optional: To prevent the overflow problem when marshalling although it is unlikely to happen.
    displayName = [displayName substringToIndex:11];
    NSLog(@"[mc_session] initialized MultipeerSession with peerID: %@", displayName);
    self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    
    // Initialize the mcSession
    self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    self.mcSession.delegate = self;
    
    self.peerID2TransportIdMap = [[NSMutableDictionary alloc] init];
    self.transportId2PeerIDMap = [[NSMutableDictionary alloc] init];
    self.browsedPeers = [[NSMutableArray alloc] init];
    self.peerID2ARSessionIdMap = [[NSMutableDictionary alloc] init];
}

- (void)sendToAllPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    bool success = [self.mcSession sendData:data toPeers:self.mcSession.connectedPeers withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session] Failed to send data to all peers");
    }
}

- (void)startBrowsing {
    self.browsedPeers = [[NSMutableArray alloc] init];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.serviceType];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
    NSLog(@"[mc_session] started browsing");
}

- (void)stopBrowsing {
    [self.browser stopBrowsingForPeers];
    NSLog(@"[mc_session] stopped browsing");
}

- (void)startAdvertising {
    // Note: If we want password, add it here.
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"DeviceName":[[UIDevice currentDevice] name] };
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:discoveryInfo serviceType:self.serviceType];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    NSLog(@"[mc_session] started advertising");
}

- (void)stopAdvertising {
    [self.advertiser stopAdvertisingPeer];
    NSLog(@"[mc_session] stopped advertising");
}

- (bool)isHost {
    if (self.advertiser != nil) {
        return YES;
    } else {
        return NO;
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerID sendDataMode:(MCSessionSendDataMode)sendDataMode {
    NSArray *peerArray = @[peerID];
    bool success = [self.mcSession sendData:data toPeers:peerArray withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[mc_session] failed to send data to peer %@", peerID.displayName);
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
    self.invitedPeerID = peerID;
    NSDictionary<NSString *, NSString *> *dict = @{ @"DeviceName":[[UIDevice currentDevice] name], @"Password":@"" };
    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:NO error:nil];
    [self.browser invitePeer:peerID toSession:self.mcSession withContext:context timeout:30];
}

- (void)sendARSessionId2AllPeers {
    NSString* arSessionId = [[ARSessionDelegateController sharedARSessionDelegateController] arSession].identifier.UUIDString;
    const char *str = [arSessionId cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 5;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
    free(data);
}

- (void)sendHostLocalIpAddress2Peer:(MCPeerID *)peerID {
    const char *str = [self.hostLocalIpAddress cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 7;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
    free(data);
}

- (void)sendPhotonRoomName2Peer:(MCPeerID *)peerID {
    const char *str = [self.photonRoomName cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 8;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
    free(data);
}

- (void)sendMPCNetcodeConnectionInvitation2Peer:(MCPeerID *)peerID {
    unsigned char data[1];
    data[0] = 9;
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:sizeof(unsigned char)];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
}

- (void)removeAllAnchorsOriginatingFromARSessionWithID:(NSString *)ARSessionId {
    ARSession *arSession = [[ARSessionDelegateController sharedARSessionDelegateController] arSession];
    for (ARAnchor *anchor in arSession.currentFrame.anchors) {
        NSString *anchorSessionId = anchor.sessionIdentifier.UUIDString;
        if ([anchorSessionId isEqualToString:ARSessionId]) {
            [arSession removeAnchor:anchor];
        }
    }
}

- (void)sendARWorldMap:(MCPeerID *)peerID {
    NSLog(@"[world map] share ARWorldMap to %@", peerID.displayName);
    NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:[[ARSessionDelegateController sharedARSessionDelegateController] worldMap] requiringSecureCoding:NO error:nil];
    [self sendToPeer:mapData peer:peerID sendDataMode:MCSessionSendDataReliable];
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"[mc_session] did receive invitation from peer %@", [peerID displayName]);
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[mc_session] found peer %@", peerID.displayName);
    
    NSString *deviceName = info[@"DeviceName"];
    NSNumber *transportId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
    [self.browsedPeers addObject:peerID];
    if (BrowserDidFindPeerDelegate != NULL) {
        BrowserDidFindPeerDelegate([transportId unsignedLongValue], [deviceName UTF8String]);
    }
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    NSLog(@"[mc_session] lost peer %@", peerID.displayName);
    [self.browsedPeers removeObject:peerID];
    if (BrowserDidLosePeerDelegate != NULL) {
        BrowserDidLosePeerDelegate([[MultipeerSession convertNSString2NSNumber:peerID.displayName] unsignedLongValue]);
    }
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch(state) {
        case MCSessionStateConnecting: {
            NSLog(@"[mc_session] connecting with peer %@", peerID.displayName);
            break;
        }
        case MCSessionStateConnected: {
            NSLog(@"[mc_session] connected with peer %@", peerID.displayName);
            NSNumber *transportId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
            [self.peerID2TransportIdMap setObject:transportId forKey:peerID];
            [self.transportId2PeerIDMap setObject:peerID forKey:transportId];
            if ([self isHost]) {
                switch(self.netcodeTransport) {
                    case NetcodeTransportUNet:
                        [self sendHostLocalIpAddress2Peer:peerID];
                        break;
                    case NetcodeTransportMPC:
                        [self sendMPCNetcodeConnectionInvitation2Peer:peerID];
                        break;
                    case NetcodeTransportPhoton:
                        [self sendPhotonRoomName2Peer:peerID];
                        break;
                }
//                if (self.arSyncMode == ARSyncModeWorldMap) {
//                    [self shareARWorldMap:peerID];
//                }
            } else {
                [self stopBrowsing];
                // Record the host peerID for possiblte reconnection in the future.
                if ([peerID isEqual:self.invitedPeerID]) {
                    self.hostPeerID = peerID;
                }
            }
            break;
        }
        case MCSessionStateNotConnected: {
            NSLog(@"[mc_session] disconnected with peer %@", peerID.displayName);
            if ([self isHost]) {
                switch(self.netcodeTransport) {
                    case NetcodeTransportUNet:
                    case NetcodeTransportPhoton:
                        break;
                    case NetcodeTransportMPC:
                        if (ClientDidDisconnectDelegate != NULL) {
                            ClientDidDisconnectDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
                        }
                        break;
                }
            } else {
                switch(self.netcodeTransport) {
                    case NetcodeTransportUNet:
                    case NetcodeTransportPhoton:
                        if ([[ARSessionDelegateController sharedARSessionDelegateController] arSession] != nil) {
                            [self startBrowsing];
                        }
                        break;
                    case NetcodeTransportMPC:
                        if (DidDisconnectFromHostDelegate != NULL) {
                            DidDisconnectFromHostDelegate();
                        }
                        break;
                }
            }
            [self.transportId2PeerIDMap removeObjectForKey:self.peerID2TransportIdMap[peerID]];
            [self.peerID2TransportIdMap removeObjectForKey:peerID];
            break;
        }
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    unsigned char *decodedData = (unsigned char *) [data bytes];
    switch ((int)decodedData[0]) {
        case 0: {
            int dataArrayLength;
            memcpy(&dataArrayLength, decodedData + 1, sizeof(int));
            unsigned char netcodeData[dataArrayLength];
            for (int i = 0; i < dataArrayLength; i++) {
                netcodeData[i] = decodedData[i + 1 + sizeof(int)];
            }
            //memcpy(netcodeData, decodedData + 1 + sizeof(int), dataArrayLength);
            unsigned long transportId = [self.peerID2TransportIdMap[peerID] unsignedLongValue];
            //DidReceivePeerDataDelegate(transportId, netcodeData, dataArrayLength);
            break;
        }
        case 4: {
            // Disconnection message
            [self.mcSession disconnect];
            if (DidDisconnectFromHostDelegate != NULL) {
                DidDisconnectFromHostDelegate();
            }
            break;
        }
        case 5: {
            // Peer ARSessionId
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *arSessionId = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            [self.peerID2ARSessionIdMap setObject:arSessionId forKey:peerID];
            free(str);
            break;
        }
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
            if (DidReceiveHostLocalIpAddressDelegate != NULL) {
                DidReceiveHostLocalIpAddressDelegate([hostLocalIpAddress UTF8String]);
            }
            free(str);
            self.netcodeTransport = NetcodeTransportUNet;
            break;
        }
        case 8: {
            // Photon room name
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *photonRoomName = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            if (DidReceivePhotonRoomNameDelegate != NULL) {
                DidReceivePhotonRoomNameDelegate([photonRoomName UTF8String]);
            }
            free(str);
            self.netcodeTransport = NetcodeTransportPhoton;
            break;
        }
        case 9: {
            // Netcode connection invitation
            if (DidReceiveMPCNetcodeConnectionInvitationDelegate != NULL) {
                DidReceiveMPCNetcodeConnectionInvitationDelegate([self.peerID2TransportIdMap[peerID] unsignedLongValue]);
            }
            self.netcodeTransport = NetcodeTransportMPC;
            break;
        }
        default: {
//            if (self.arSyncMode == ARSyncModeCollaboration) {
//                ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
//                if (collaborationData != nil) {
//                    [[ARSessionDelegateController sharedARSessionDelegateController] updateWithCollaborationData:collaborationData];
//                    return;
//                }
//            }
            
            ARWorldMap *worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:data error:nil];
            if (worldMap != nil) {
                NSLog(@"[world_map] did receive ARWorldMap of size %f mb", data.length / 1024.0 / 1024.0);
                [[ARSessionDelegateController sharedARSessionDelegateController] setWorldMap:worldMap];
                if (DidReceiveARWorldMapDelegate != NULL) {
                    DidReceiveARWorldMapDelegate();
                }
                return;
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
UnityHoloKit_MPCInitialize(const char* serviceType) {
    MultipeerSession* mc_session = [MultipeerSession sharedMultipeerSession];
    [mc_session initializeWithServiceType:[NSString stringWithUTF8String:serviceType]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStartBrowsing(void) {
    [[MultipeerSession sharedMultipeerSession] startBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStartAdvertising(void) {
    [[MultipeerSession sharedMultipeerSession] startAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStopBrowsing(void) {
    [[MultipeerSession sharedMultipeerSession] stopBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStopAdvertising(void) {
    [[MultipeerSession sharedMultipeerSession] stopAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCDeinitialize(void) {
    MultipeerSession *multipeerSession = [MultipeerSession sharedMultipeerSession];
    if ([[multipeerSession.mcSession connectedPeers] count] > 0)
        [multipeerSession.mcSession disconnect];
    [multipeerSession setMcSession:nil];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(BrowserDidFindPeer callback) {
    BrowserDidFindPeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(BrowserDidLosePeer callback) {
    BrowserDidLosePeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCInvitePeer(unsigned long transportId) {
    MultipeerSession *multipeerSession = [MultipeerSession sharedMultipeerSession];
    for (MCPeerID *peerID in multipeerSession.browsedPeers) {
        if (transportId == [[MultipeerSession convertNSString2NSNumber:peerID.displayName] unsignedLongValue]) {
            [multipeerSession invitePeer:peerID];
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SendDidResetARSessionMessage(void) {
//    unsigned char message[1];
//    message[0] = (unsigned char)6;
//    NSData *dataReadyToBeSent = [NSData dataWithBytes:message length:sizeof(message)];
//    [[[ARSessionDelegateController sharedARSessionDelegateController] multipeerSession] sendToAllPeers:dataReadyToBeSent sendDataMode:MCSessionSendDataReliable];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveARWorldMapDelegate(DidReceiveARWorldMap callback) {
    DidReceiveARWorldMapDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetHostLocalIpAddress(const char *ip) {
    //[[[ARSessionDelegateController sharedARSessionDelegateController] multipeerSession] setHostLocalIpAddress:[NSString stringWithUTF8String:ip]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetPhotonRoomName(const char *roomName) {
    //[[[ARSessionDelegateController sharedARSessionDelegateController] multipeerSession] setPhotonRoomName:[NSString stringWithUTF8String:roomName]];
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
    //[[[ARSessionDelegateController sharedARSessionDelegateController] multipeerSession] setNetcodeTransport:(NetcodeTransport)transport];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidReceiveMPCNetcodeConnectionInvitationDelegate(DidReceiveMPCNetcodeConnectionInvitation callback) {
    DidReceiveMPCNetcodeConnectionInvitationDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetClientDidDisconnectDelegate(ClientDidDisconnect callback) {
    ClientDidDisconnectDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetDidDisconnectFromHostDelegate(DidDisconnectFromHost callback) {
    DidDisconnectFromHostDelegate = callback;
}
