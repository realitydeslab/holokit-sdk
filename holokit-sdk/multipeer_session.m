//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#include "IUnityInterface.h"
#include "ar_session.h"

typedef void (*MultipeerSendConnectionRequestForMLAPI)(unsigned long peerId);
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

@end

@implementation MultipeerSession

- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler {
    self = [super init];
    if (self) {
        self.serviceType = @"ar-collab";
        self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
        NSLog(@"[multipeer_session]: my peerID %@", self.myPeerID);
        
        // TODO: If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.session = [[MCSession alloc] initWithPeer:self.myPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.session.delegate = self;
        
        self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID discoveryInfo:nil serviceType:self.serviceType];
        self.serviceAdvertiser.delegate = self;
        [self.serviceAdvertiser startAdvertisingPeer];
        
        self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID serviceType:self.serviceType];
        self.serviceBrowser.delegate = self;
        [self.serviceBrowser startBrowsingForPeers];
         
        self.receivedDataHandler = receivedDataHandler;
    }
    return self;
}

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
        
        self.connectedPeers = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)sendToAllPeers: (NSData *)data {
    //NSLog(@"[ar_session]: send to all peers.");
    if (self.session.connectedPeers.count == 0) {
        NSLog(@"[multipeer_session]: There is no connected peer.");
        return;
    }
    // TODO: Client only sends data to the server.
    bool success = [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    if (success) {
        //NSLog(@"Send to all peers successfully.");
    } else {
        NSLog(@"Send to all peers unsuccessfully");
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerId mode:(MCSessionSendDataMode)mode {
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
            result = MCSessionSendDataReliable;
            break;
        case(6):
            // PositionUpdate
            result = MCSessionSendDataReliable;
            break;
        case(7):
            // AnimationUpdate
            result = MCSessionSendDataReliable;
            break;
        case(8):
            // NavAgentState
            result = MCSessionSendDataReliable;
            break;
        case(9):
            // NavAgentCorrection
            result = MCSessionSendDataReliable;
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
        [self.connectedPeers removeObject:peerID];
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
            [self.connectedPeers addObject:peerID];
            // Notify the host that there is a new peer joining the session.
            
        } else {
            // As a client, we only need to connect to the server.
            if (self.connectedPeers.count == 0) {
                [self.connectedPeers addObject:peerID];
                
                unsigned long serverId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
                NSLog(@"[multipeer_session]: send connection request to server %lu", serverId);
                MultipeerSendConnectionRequestForMLAPIDelegate(serverId);
            }
        }
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    //NSLog(@"[multipeer_session]: did receive data from peer %@", peerID.displayName);
    self.receivedDataHandler(data, peerID);
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
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
    MultipeerSession *session = ar_session_delegate_controller.multipeerSession;
    for (MCPeerID *peerId in session.connectedPeers) {
        if (clientId == [[NSNumber numberWithInteger:[peerId.displayName integerValue]] unsignedLongValue]) {
            unsigned char niceData[dataArrayLength + 2];
            // Append the MLAPI NetworkChannel at the beginning of the data
            niceData[0] = (unsigned char)channel;
            // Append the length of the data array at the second place
            niceData[1] = (unsigned char)dataArrayLength;
            // TODO: is there a better way to do this? I mean copying array
            for (int i = 2; i < dataArrayLength + 2; i++) {
                niceData[i] = data[i - 2];
            }
//            NSLog(@"[multipeer_session]: size of the data before sent %d", sizeof(niceData));
            // Convert the data to NSData format
            // https://stackoverflow.com/questions/8354881/convert-unsigned-char-array-to-nsdata-and-back
            NSData *convertedData = [NSData dataWithBytes:niceData length:sizeof(niceData)];
            // Send the data
            [session sendToPeer:convertedData peer:peerId mode:[MultipeerSession convertMLAPINetworkChannelToSendDataMode:channel]];
            return;
        }
    }
}
