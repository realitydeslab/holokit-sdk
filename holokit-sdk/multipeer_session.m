//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#import "IUnityInterface.h"
#import "ar_session.h"

typedef void (*InitializeClientId)(unsigned long clientId);
InitializeClientId InitializeClientIdDelegate = NULL;

typedef void (*BrowserDidFindPeer)(const char *deviceName, unsigned long clientId);
BrowserDidFindPeer BrowserDidFindPeerDelegate = NULL;

typedef void (*BrowserDidLosePeer)(unsigned long clientId);
BrowserDidLosePeer BrowserDidLosePeerDelegate = NULL;

typedef void (*NewPeerDidConnect)(unsigned long clientId);
NewPeerDidConnect NewPeerDidConnectDelegate = NULL;

typedef void (*DidReceiveDisconnectionMessageFromClient)(unsigned long clientId);
DidReceiveDisconnectionMessageFromClient DidReceiveDisconnectionMessageFromClientDelegate = NULL;

typedef void (*DidReceivePeerData)(unsigned long clientId, unsigned char *data, int dataArrayLength);
DidReceivePeerData DidReceivePeerDataDelegate = NULL;

typedef void (*DidReceivePongMessage)(unsigned long clientId, double rtt);
DidReceivePongMessage DidReceivePongMessageDelegate = NULL;

typedef enum {
    MLAPIData,
    Ping,
    Pong,
    Disconnection
} MultipeerDataType;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *localPeerID;
@property (nonatomic, strong) MCSession *mcSession;
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *peerName2ClientIdMap;
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
        displayName = [displayName substringToIndex:10];
        NSLog(@"[mc_session]: local peer display name: %@", displayName);
        self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        
        // If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.mcSession.delegate = self;
        
        self.connectedPeersForUnity = [[NSMutableArray alloc] init];
        self.peerName2ClientIdMap = [[NSMutableDictionary alloc] init];
        self.browsedPeers = [[NSMutableArray alloc] init];
        
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

- (void)sendToAllUnityPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    if (self.connectedPeersForUnity.count == 0) {
        NSLog(@"[multipeer_session]: There is no connected Unity peer.");
        return;
    }
    bool success = [self.mcSession sendData:data toPeers:self.connectedPeersForUnity withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session]: Failed to send data to all Unity peers.");
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
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"PeerName":[[UIDevice currentDevice] name], @"RequirePassword": @"No" };
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

- (NSString *)getLocalPeerDisplayName {
    return self.localPeerID.displayName;
}

- (void)invitePeer:(unsigned long)clientId {
    for (MCPeerID *peerID in self.browsedPeers) {
        if (clientId == [self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            NSDictionary<NSString *, NSString *> *dict = @{ @"DeviceName":[[UIDevice currentDevice] name], @"Password":@"" };
            NSData *context = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:NO error:nil];
            [self.browser invitePeer:peerID toSession:self.mcSession withContext:context timeout:30];
        }
    }
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    //NSDictionary<NSString *, NSString *> *dict = (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:context];
    NSDictionary<NSString *, NSString *> *dict = [NSKeyedUnarchiver unarchivedDictionaryWithKeysOfClass:[NSString class] objectsOfClass:[NSString class] fromData:context error:nil];
    if (dict != nil) {
        NSLog(@"[mc_session]: inviter device name %@", dict[@"DeviceName"]);
    }
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSString *peerName = info[@"PeerName"];
    NSNumber *clientId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
    if (self.peerName2ClientIdMap[peerID.displayName] == nil) {
        [self.peerName2ClientIdMap setObject:clientId forKey:peerID.displayName];
    }
    [self.browsedPeers addObject:peerID];
    if (BrowserDidFindPeerDelegate != NULL) {
        BrowserDidFindPeerDelegate([peerName UTF8String], [clientId unsignedLongValue]);
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
            NSLog(@"[mc_session]: Connecting with peer %@.", peerID.displayName);
            break;
        case MCSessionStateConnected:
            NSLog(@"[mc_session]: Connected with peer %@.", peerID.displayName);
            if ([self isHost]) {
                [self.connectedPeersForUnity addObject:peerID];
                [self.peerName2ClientIdMap setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
                NewPeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]);
            } else {
//                if (self.connectedPeersForUnity.count == 0) {
//                    [self.connectedPeersForUnity addObject:peerID];
//                    [self.peerName2ClientIdMap setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
//                    NewPeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]);
//                }
            }
            break;
        case MCSessionStateNotConnected:
            NSLog(@"[mc_session]: Disconnected with peer %@.", peerID.displayName);
            [self.connectedPeersForUnity removeObject:peerID];
            // Notify MLAPI that a client is disconnected.
            if (self.advertiser != nil) {
                unsigned long clientId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
                DidReceiveDisconnectionMessageFromClientDelegate(clientId);
            }
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    // First try to decode the received data as ARCollaboration data.
    ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
    if (collaborationData != nil) {
        [[HoloKitARSession sharedARSession] updateWithHoloKitCollaborationData:collaborationData];
        return;
    }

    unsigned char *decodedData = (unsigned char *) [data bytes];
    if (decodedData == nil) {
        NSLog(@"[ar_session]: Failed to decode the received data.");
        return;
    }
    switch ((int)decodedData[0]) {
        case 0: {
            //NSLog(@"[ar_session]: did receive Netcode data.");
            int dataArrayLength = (int)decodedData[1];
            unsigned char mlapiData[dataArrayLength];
            for (int i = 0; i < dataArrayLength; i++) {
                mlapiData[i] = decodedData[i + 2];
            }
            unsigned long clientId = [self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue];
            DidReceivePeerDataDelegate(clientId, mlapiData, dataArrayLength);
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
            NSLog(@"[mc_session]: did receive a connection message");
            [self.connectedPeersForUnity addObject:peerID];
            [self.peerName2ClientIdMap setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
            NewPeerDidConnectDelegate([self.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]);
            break;
        }
        case 4: {
            NSLog(@"[mc_session]: Did receive a disconnection message.");
            [self.mcSession disconnect];
            break;
        }
        default: {
            NSLog(@"[mc_session]: Failed to decode the received data.");
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
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    ar_session_instance.multipeerSession = [[MultipeerSession alloc] initWithServiceType:[NSString stringWithUTF8String:serviceType]];
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
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeerSession = ar_session_instance.multipeerSession;
    for (MCPeerID *peerID in multipeerSession.connectedPeersForUnity) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            unsigned char structuredData[dataArrayLength + 3];
            // Append the data type at the beginning of the array
            structuredData[0] = (unsigned char)0;
            // Append the length of the data array at the third place
            structuredData[1] = (unsigned char)dataArrayLength;
            // TODO: is there a better way to do this? I mean copying array
            for (int i = 2; i < dataArrayLength + 2; i++) {
                structuredData[i] = data[i - 2];
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
    for (MCPeerID *peerID in multipeerSession.connectedPeersForUnity) {
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
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeer_session = ar_session_instance.multipeerSession;
    
    [multipeer_session.mcSession disconnect];
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCDisconnectRemoteClient(unsigned long clientId) {
    HoloKitARSession* ar_session_delegate_controller = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeer_session = ar_session_delegate_controller.multipeerSession;
    if (![multipeer_session isHost]) {
        return;
    }
    
    for (MCPeerID *peerID in multipeer_session.connectedPeersForUnity) {
        if (clientId == [multipeer_session.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            // Prepare the disconnection message
            unsigned char disconnectionData[1];
            disconnectionData[0] = (unsigned char)3;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
            [multipeer_session sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
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
    UnityHoloKit_MCDisconnectAllClients();
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    [ar_session_instance.multipeerSession.mcSession disconnect];
    ar_session_instance.multipeerSession = nil;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetNewPeerDidConnectDelegate(NewPeerDidConnect callback) {
    NewPeerDidConnectDelegate = callback;
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
UnityHoloKit_SetDidReceiveDisconnectionMessageFromClientDelegate(DidReceiveDisconnectionMessageFromClient callback) {
    DidReceiveDisconnectionMessageFromClientDelegate = callback;
}

unsigned long UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCGetServerClientId(void) {
    return [[MultipeerSession convertNSString2NSNumber:[[[HoloKitARSession sharedARSession] multipeerSession] getLocalPeerDisplayName]] unsignedLongValue];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCInvitePeer(unsigned long clientId) {
    [[[HoloKitARSession sharedARSession] multipeerSession] invitePeer:clientId];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendConnectionMessage2Client(unsigned long clientId) {
    MultipeerSession *multipeerSession = [[HoloKitARSession sharedARSession] multipeerSession];
    for (MCPeerID *peerID in multipeerSession.connectedPeersForUnity) {
        if (clientId == [multipeerSession.peerName2ClientIdMap[peerID.displayName] unsignedLongValue]) {
            NSLog(@"[mc_session]: send connection message to client");
            unsigned char connectionMessageData[1];
            connectionMessageData[0] = (unsigned char)3;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:connectionMessageData length:sizeof(connectionMessageData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
        }
    }
}
