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

typedef void (*SendConnectionRequest2Server)(unsigned long serverId);
SendConnectionRequest2Server SendConnectionRequest2ServerDelegate = NULL;

typedef void (*DidReceiveDisconnectionMessageFromClient)(unsigned long clientId);
DidReceiveDisconnectionMessageFromClient DidReceiveDisconnectionMessageFromClientDelegate = NULL;

typedef void (*DidReceivePeerData)(unsigned long clientId, unsigned char *data, int dataArrayLength, int channel);
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
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *serviceAdvertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *serviceBrowser;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *peerClientIds;

@end

@implementation MultipeerSession

- (instancetype)initWithServiceType:(NSString *)serviceType {
    self = [super init];
    if (self) {
        self.serviceType = serviceType;
        NSString *deviceName = [UIDevice currentDevice].name;
        NSString *systemUptime = [[NSNumber numberWithDouble:[[NSProcessInfo processInfo] systemUptime]] stringValue];
        NSString *displayNameBeforeHash = [NSString stringWithFormat:@"%@%@", deviceName, systemUptime];
        NSString *displayName = [NSString stringWithFormat:@"%lu", [displayNameBeforeHash hash]];
        self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        
        // If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.mcSession.delegate = self;
        
        self.connectedPeersForUnity = [[NSMutableArray alloc] init];
        self.peerClientIds = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)sendToAllPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    if (self.connectedPeersForUnity.count == 0) {
        NSLog(@"[multipeer_session]: There is no connected MLAPI peer.");
        return;
    }
    bool success = [self.mcSession sendData:data toPeers:self.connectedPeersForUnity withMode:sendDataMode error:nil];
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
    self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.serviceType];
    self.serviceBrowser.delegate = self;
    [self.serviceBrowser startBrowsingForPeers];

}

- (void)stopBrowsing {
    [self.serviceBrowser stopBrowsingForPeers];
}

- (void)startAdvertising {
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"PeerName": self.localPeerID.displayName, @"Password": @"No" };
    self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:discoveryInfo serviceType:self.serviceType];
    self.serviceAdvertiser.delegate = self;
    [self.serviceAdvertiser startAdvertisingPeer];
}

- (void)stopAdvertising {
    [self.serviceAdvertiser stopAdvertisingPeer];
}

- (bool)isHost {
    if (self.serviceAdvertiser != nil) {
        return YES;
    } else {
        return NO;
    }
}

+ (MCSessionSendDataMode)convertMLAPINetworkChannelToSendDataMode:(int)channel {
    MCSessionSendDataMode result = MCSessionSendDataReliable;
    switch(channel) {
        case(0):
            // Internal
            result = MCSessionSendDataReliable;
            break;
        case(1):
            // TimeSync
            result = MCSessionSendDataReliable;
            break;
        case(2):
            // ReliableRpc
            result = MCSessionSendDataReliable;
            break;
        case(3):
            // UnreliableRpc
            result = MCSessionSendDataUnreliable;
            break;
        case(4):
            // SyncChannel
            result = MCSessionSendDataReliable;
            break;
        case(5):
            // DefaultMessage
            // TODO: Check again
            result = MCSessionSendDataReliable;
            break;
        case(6):
            // PositionUpdate
            result = MCSessionSendDataUnreliable;
            break;
        case(7):
            // AnimationUpdate
            result = MCSessionSendDataUnreliable;
            break;
        case(8):
            // NavAgentState
            result = MCSessionSendDataUnreliable;
            break;
        case(9):
            // NavAgentCorrection
            result = MCSessionSendDataUnreliable;
            break;
        case(10):
            // ChannelUnused
            result = MCSessionSendDataUnreliable;
            break;
        default:
            result = MCSessionSendDataUnreliable;
            break;
    }
    return result;
}

+ (int)multipeerDataType2DataIndex:(MultipeerDataType)dataType {
    int result;
    switch(dataType) {
        case MLAPIData:
            result = 0;
            break;
        case Ping:
            result = 1;
            break;
        case Pong:
            result = 2;
            break;
        case Disconnection:
            result = 3;
            break;
        default:
            result = -1;
            break;
    }
    return result;
}

+ (NSNumber *)convertNSString2NSNumber:(NSString *)str {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter numberFromString:str];
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch(state) {
        case MCSessionStateConnecting:
            NSLog(@"[multipeer_session]: Connecting with peer %@.", peerID.displayName);
            break;
        case MCSessionStateConnected:
            NSLog(@"[multipeer_session]: Connected with peer %@.", peerID.displayName);
            if ([self isHost]) {
                [self.connectedPeersForUnity addObject:peerID];
                [self.peerClientIds setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
            } else {
                if (self.connectedPeersForUnity.count == 0) {
                    [self.connectedPeersForUnity addObject:peerID];
                    [self.peerClientIds setObject:[MultipeerSession convertNSString2NSNumber:peerID.displayName] forKey:peerID.displayName];
                    SendConnectionRequest2ServerDelegate([self.peerClientIds[peerID.displayName] unsignedLongValue]);
                }
            }
            break;
        case MCSessionStateNotConnected:
            NSLog(@"[multipeer_session]: Disconnected with peer %@.", peerID.displayName);
            [self.connectedPeersForUnity removeObject:peerID];
            // Notify MLAPI that a client is disconnected.
            if (self.serviceAdvertiser != nil) {
                unsigned long clientId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
                DidReceiveDisconnectionMessageFromClientDelegate(clientId);
            }
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    // We only handle data that was sent from a connected MLAPI peer.
    if (![self.connectedPeersForUnity containsObject:peerID]) {
        return;
    }
    
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
            //NSLog(@"[ar_session]: did receive MLAPI data.");
            int channel = (int)decodedData[1];
            int dataArrayLength = (int)decodedData[2];
            unsigned char mlapiData[dataArrayLength];
            for (int i = 0; i < dataArrayLength; i++) {
                mlapiData[i] = decodedData[i + 3];
            }
            unsigned long clientId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
            // Send this data back to MLAPI
            DidReceivePeerDataDelegate(clientId, mlapiData, dataArrayLength, channel);
            break;
        }
        case 1: {
            // Did receive a Ping data
            // Send a Pong message back
            unsigned char pongMessageData[1];
            pongMessageData[0] = (unsigned char)2;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pongMessageData length:sizeof(pongMessageData)];
            [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataUnreliable];
            break;
        }
        case 2: {
            // Did receive a Pong message
            double rtt = ([[NSProcessInfo processInfo] systemUptime] - self.lastPingTime) * 1000;
            //NSLog(@"[mc_session]: curernt rtt is %f", rtt);
            unsigned long clientId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
            DidReceivePongMessageDelegate(clientId, rtt);
            break;
        }
        case 3: {
            NSLog(@"[ar_session]: Did receive a disconnection message.");
            [self.mcSession disconnect];
            break;
        }
        default: {
            NSLog(@"[ar_session]: Failed to decode the received data.");
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

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"[multipeer_session]: Did receive invitation from peer %@.", peerID.displayName);
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[multipeer_session]: Browsed a peer %@.", peerID.displayName);
    [browser invitePeer:peerID toSession:self.mcSession withContext:nil timeout:30];
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    NSLog(@"[multipeer_session]: Lost peer %@.", peerID.displayName);
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

// 0 for normal MLAPI data
// 1 for ping message
// 2 for pong message
// 3 for disconnection message
// https://stackoverflow.com/questions/3426491/how-can-you-marshal-a-byte-array-in-c
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendData(unsigned long clientId, unsigned char *data, int dataArrayLength, int channel) {
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeerSession = ar_session_instance.multipeerSession;
    for (MCPeerID *peerId in multipeerSession.connectedPeersForUnity) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            unsigned char structuredData[dataArrayLength + 3];
            // Append the data type at the beginning of the data array
            structuredData[0] = (unsigned char)0;
            // Append the MLAPI NetworkChannel at the second place
            structuredData[1] = (unsigned char)channel;
            // Append the length of the data array at the third place
            structuredData[2] = (unsigned char)dataArrayLength;
            // TODO: is there a better way to do this? I mean copying array
            for (int i = 3; i < dataArrayLength + 3; i++) {
                structuredData[i] = data[i - 3];
            }

            // Convert the data to NSData format
            // https://stackoverflow.com/questions/8354881/convert-unsigned-char-array-to-nsdata-and-back
            NSData *dataReadyToBeSent = [NSData dataWithBytes:structuredData length:sizeof(structuredData)];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerId sendDataMode:[MultipeerSession convertMLAPINetworkChannelToSendDataMode:channel]];
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MCSendPingMessage(unsigned long clientId) {
    //NSLog(@"send %@", [NSThread currentThread]);
    HoloKitARSession* ar_session_instance = [HoloKitARSession sharedARSession];
    MultipeerSession *multipeerSession = ar_session_instance.multipeerSession;
    for (MCPeerID *peerId in multipeerSession.connectedPeersForUnity) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            // Prepare the Ping message
            unsigned char pingMessageData[1];
            pingMessageData[0] = (unsigned char)1;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pingMessageData length:sizeof(pingMessageData)];
            multipeerSession.lastPingTime = [[NSProcessInfo processInfo] systemUptime];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerId sendDataMode:MCSessionSendDataUnreliable];
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
    
    for (MCPeerID *peerId in multipeer_session.connectedPeersForUnity) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            // Prepare the disconnection message
            unsigned char disconnectionData[1];
            disconnectionData[0] = (unsigned char)3;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
            [multipeer_session sendToPeer:dataReadyToBeSent peer:peerId sendDataMode:MCSessionSendDataReliable];
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
    disconnectionData[0] = (unsigned char)3;
    
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
UnityHoloKit_SetSendConnectionRequest2ServerDelegate(SendConnectionRequest2Server callback) {
    SendConnectionRequest2ServerDelegate = callback;
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
