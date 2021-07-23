//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#include "IUnityInterface.h"
#include "ar_session.h"

typedef void (*MultipeerSendConnectionRequestForMLAPI)(unsigned long serverId);
MultipeerSendConnectionRequestForMLAPI MultipeerSendConnectionRequestForMLAPIDelegate = NULL;

typedef void (*MultipeerDisconnectionMessageReceivedForMLAPI)(unsigned long clientId);
MultipeerDisconnectionMessageReceivedForMLAPI MultipeerDisconnectionMessageReceivedForMLAPIDelegate = NULL;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *myPeerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *serviceAdvertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *serviceBrowser;
// Reference: http://fuckingblocksyntax.com/
@property (nonatomic, copy, nullable) void (^receivedDataHandler)(NSData *, MCPeerID *);
@property (nonatomic, strong, nullable) NSMutableArray<InputStreamForMLAPI *> *inputStreams;

@end

@implementation MultipeerSession

// This constructor is for MLAPI.
- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler serviceType:(NSString *)serviceType peerID:(NSString *)peerID {
    self = [super init];
    if (self) {
        self.serviceType = serviceType;
        self.myPeerID = [[MCPeerID alloc] initWithDisplayName:peerID];
        NSLog(@"[multipeer_session]: service type is %@ and peerID display name is %@", serviceType, peerID);
        
        // TODO: If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.session = [[MCSession alloc] initWithPeer:self.myPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.session.delegate = self;

        self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID discoveryInfo:nil serviceType:self.serviceType];
        self.serviceAdvertiser.delegate = self;
        //[self.serviceAdvertiser startAdvertisingPeer];

        self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID serviceType:self.serviceType];
        self.serviceBrowser.delegate = self;
        //[self.serviceBrowser startBrowsingForPeers];

        self.receivedDataHandler = receivedDataHandler;
        
        self.connectedPeersForMLAPI = [[NSMutableArray alloc] init];
        self.outputStreams = [[NSMutableDictionary alloc] init];
        self.inputStreams = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)sendToAllPeers: (NSData *)data mode:(MCSessionSendDataMode)mode {
    //NSLog(@"[ar_session]: send to all peers.");
    if (self.connectedPeersForMLAPI.count == 0) {
        NSLog(@"[multipeer_session]: There is no connected peer.");
        return;
    }
    // Client only sends data to the server.
    bool success = [self.session sendData:data toPeers:self.connectedPeersForMLAPI withMode:mode error:nil];
    if (success) {
        //NSLog(@"Send to all peers successfully.");
    } else {
        NSLog(@"Send to all peers unsuccessfully");
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerId mode:(MCSessionSendDataMode)mode {
    //NSLog(@"sendToPeer %@", [NSThread currentThread]);
    //NSLog(@"[multipeer_session]: send to peer %@", peerId.displayName);
    NSArray *peerArray = @[peerId];
    bool success = [self.session sendData:data toPeers:peerArray withMode:mode error:nil];
    if (success) {
        //NSLog(@"[multipeer_session]: successfully sent data to peer.");
    } else {
        NSLog(@"[multipeer_session]: failed to send to peer.");
    }
}

- (NSArray<MCPeerID *> *)getConnectedPeers {
    return self.session.connectedPeers;
}

- (void)startBrowsing {
    NSLog(@"[multipeer_session]: startBrowsing");
    self.isHost = true;
    [self.serviceBrowser startBrowsingForPeers];
}

- (void)startAdvertising {
    NSLog(@"[multipeer_session]: startAdvertising");
    self.isHost = false;
    [self.serviceAdvertiser startAdvertisingPeer];
}

- (void)disconnect {
    [self.session disconnect];
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

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateNotConnected) {
        NSLog(@"[multipeer_session]: disconnected with peer %@.", peerID.displayName);
        [self.connectedPeersForMLAPI removeObject:peerID];
        // TODO: Notify MLAPI that a client is disconnected.
        if (self.isHost) {
            unsigned long clientId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
            MultipeerDisconnectionMessageReceivedForMLAPIDelegate(clientId);
        }
    } else if (state == MCSessionStateConnecting) {
        NSLog(@"[multipeer_session]: connecting with peer %@.", peerID.displayName);
    } else if (state == MCSessionStateConnected) {
        NSLog(@"[multipeer_session]: connected with peer %@.", peerID.displayName);
        if (self.isHost) {
            [self.connectedPeersForMLAPI addObject:peerID];
            
            // Set a byte stream channel
            // https://gist.github.com/lucasecf/bde1d9bd3492f29b7534
//            NSOutputStream *newOutputStream = [session startStreamWithName:@"MLAPI" toPeer:peerID error:nil];
//            [self.outputStreams setObject:newOutputStream forKey:peerID];
//            if (newOutputStream != nil) {
//                //newOutputStream.delegate = self;
//                [newOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
//                [newOutputStream open];
//            }
        } else {
            // As a client, we only need to connect to the server.
            if (self.connectedPeersForMLAPI.count == 0) {
                [self.connectedPeersForMLAPI addObject:peerID];
                
//                // Set the byte stream channel before MLAPI gets connected.
//                NSOutputStream *newOutputStream = [session startStreamWithName:@"MLAPI" toPeer:peerID error:nil];
//                [self.outputStreams setObject:newOutputStream forKey:peerID];
//                if (newOutputStream != nil) {
//                    //newOutputStream.delegate = self;
//                    [newOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
//                    [newOutputStream open];
//                }
                
                unsigned long serverId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
                //NSLog(@"[multipeer_session]: send connection request to server %lu", serverId);
                MultipeerSendConnectionRequestForMLAPIDelegate(serverId);
            }
        }
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    //NSLog(@"didReceiveData %@", [NSThread currentThread]);
    //NSLog(@"[multipeer_session]: did receive data from peer %@", peerID.displayName);
    //self.receivedDataHandler(data, peerID);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.receivedDataHandler(data, peerID);
    });
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    //NSLog(@"[mc_session]: did receive stream");
    if ([streamName isEqual:@"MLAPI"]) {
        if ([self.connectedPeersForMLAPI containsObject:peerID]) {
            InputStreamForMLAPI *newInputStream = [[InputStreamForMLAPI alloc] initWithMultipeerSession:self peerID:peerID];
            [self.inputStreams addObject:newInputStream];
            stream.delegate = newInputStream;
            [stream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            [stream open];
            NSLog(@"[mc_session]: intput stream opened");
        }
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"[multipeer_session]: did receive invitation from peer %@.", peerID.displayName);
    invitationHandler(true, self.session);
    // TODO: notify MLAPI
}

//- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
//    NSLog(@"[multipeer_session]: did receive invitation from peer.");
//}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[multipeer_session]: found peer %@.", peerID.displayName);
    // Invite the found peer into my MCSession.
    [browser invitePeer:peerID toSession:self.session withContext:nil timeout:10];
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    NSLog(@"[multipeer_session]: lost peer %@.", peerID.displayName);
}

@end

#pragma mark - StreamForMLAPI

@interface InputStreamForMLAPI()

@end

@implementation InputStreamForMLAPI

- (instancetype)initWithMultipeerSession:(MultipeerSession *)multipeerSession peerID:(MCPeerID *)peerID {
    self = [super init];
    if (self) {
        self.multipeerSession = multipeerSession;
        self.peerID = peerID;
    }
    return self;
}

// https://gist.github.com/lucasecf/bde1d9bd3492f29b7534
// https://github.com/lianhuaren/cocoa/blob/04e46392d51018ed589e46d5114079d6ed3e3946/rtmp01/SGLivingPublisher-master/SGLivingPublisher/SGRTMPKit/Rtmp/SGStreamSession.m
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    //NSLog(@"didReceiveStreamData %@", [NSThread currentThread]);
    //NSLog(@"[input_stream]: did receive new stream data");
    if (eventCode == NSStreamEventHasBytesAvailable) {
        // TODO: Is this size appropriate?
        uint8_t buffer[1024];
        NSUInteger len = [(NSInputStream *)aStream read:buffer maxLength:sizeof(buffer)];
        NSData *data = [NSData dataWithBytes:buffer length:len];
        [self.multipeerSession session:self.multipeerSession.session didReceiveData:data fromPeer:self.peerID];
    }
}

@end

#pragma mark - extern "C"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetMultipeerSendConnectionRequestForMLAPIDelegate(MultipeerSendConnectionRequestForMLAPI callback) {
    MultipeerSendConnectionRequestForMLAPIDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_SetMultipeerDisconnectionMessageReceivedForMLAPIDelegate(MultipeerDisconnectionMessageReceivedForMLAPI callback) {
    MultipeerDisconnectionMessageReceivedForMLAPIDelegate = callback;
}

// https://stackoverflow.com/questions/3426491/how-can-you-marshal-a-byte-array-in-c
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerSendDataForMLAPI(unsigned long clientId, unsigned char *data, int dataArrayLength, int channel) {
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *multipeerSession = ar_session_delegate_controller.multipeerSession;
    for (MCPeerID *peerId in multipeerSession.connectedPeersForMLAPI) {
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
//            NSLog(@"[multipeer_session]: size of the data before sent %d", sizeof(niceData));
            // Convert the data to NSData format
            // https://stackoverflow.com/questions/8354881/convert-unsigned-char-array-to-nsdata-and-back
            NSData *dataReadyToBeSent = [NSData dataWithBytes:structuredData length:sizeof(structuredData)];
            // Send the data
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerId mode:[MultipeerSession convertMLAPINetworkChannelToSendDataMode:channel]];
            return;
        }
    }
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerDisconnectAllPeersForMLAPI(void) {
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *session = ar_session_delegate_controller.multipeerSession;
    
    // Prepare the disconnection message
    unsigned char disconnectionData[1];
    disconnectionData[0] = (unsigned char)1;
    
    NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
    [session sendToAllPeers:dataReadyToBeSent mode:MCSessionSendDataReliable];
}

// https://stackoverflow.com/questions/20316848/multipeer-connectivity-programmatically-disconnect-a-peer
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerDisconnectPeerForMLAPI(unsigned long clientId) {
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *session = ar_session_delegate_controller.multipeerSession;
    for (MCPeerID *peerId in session.connectedPeersForMLAPI) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            // Prepare the disconnection message
            unsigned char disconnectionData[1];
            disconnectionData[0] = (unsigned char)1;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:disconnectionData length:sizeof(disconnectionData)];
            [session sendToPeer:dataReadyToBeSent peer:peerId mode:MCSessionSendDataReliable];
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerDisconnectForMLAPI(void) {
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *session = ar_session_delegate_controller.multipeerSession;
    
    [session.session disconnect];
}

// 0 for normal MLAPI data
// 1 for disconnection message
// 2 for ping message
// 3 for pong message

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerSendPingMessage(unsigned long clientId) {
    //NSLog(@"send %@", [NSThread currentThread]);
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *multipeerSession = ar_session_delegate_controller.multipeerSession;
    for (MCPeerID *peerId in multipeerSession.connectedPeersForMLAPI) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            // Prepare the Ping message
            unsigned char pingMessageData[1];
            pingMessageData[0] = (unsigned char)2;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pingMessageData length:sizeof(pingMessageData)];
            multipeerSession.lastPingTime = [[NSProcessInfo processInfo] systemUptime];
            [multipeerSession sendToPeer:dataReadyToBeSent peer:peerId mode:MCSessionSendDataUnreliable];
            return;
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MultipeerSendPingMessageViaStream(unsigned long clientId) {
    //NSLog(@"sendViaStream %@", [NSThread currentThread]);
    ARSessionDelegateController* ar_session_delegate_controller = [ARSessionDelegateController sharedARSessionDelegateController];
    MultipeerSession *multipeerSession = ar_session_delegate_controller.multipeerSession;
    for (MCPeerID *peerID in multipeerSession.connectedPeersForMLAPI) {
        if (clientId == [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue]) {
            // Prepare the Ping message
            unsigned char pingMessageData[1];
            pingMessageData[0] = (unsigned char)2;
            NSData *dataReadyToBeSent = [NSData dataWithBytes:pingMessageData length:sizeof(pingMessageData)];
            if (multipeerSession.outputStreams[peerID] != nil) {
                //NSLog(@"[mc_session]: write to output stream");
                multipeerSession.lastPingTime = [[NSProcessInfo processInfo] systemUptime];
                [multipeerSession.outputStreams[peerID] write:dataReadyToBeSent.bytes maxLength:dataReadyToBeSent.length];
            }
            return;
        }
    }
}
