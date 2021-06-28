//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"

typedef void (*MultipeerConnectionStartedForMLAPI)(unsigned long peerId);
MultipeerConnectionStartedForMLAPI MultipeerConnectionStartedForMLAPIDelegate = NULL;

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

//- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler {
//    self = [super init];
//    
//    if (self) {
//        self.serviceType = @"ar-collab";
//        self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
//        NSLog(@"%@", self.myPeerID);
//        
//        // TODO: If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
//        self.session = [[MCSession alloc] initWithPeer:self.myPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
//        self.session.delegate = self;
//        
//        self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID serviceType:self.serviceType];
//        self.serviceBrowser.delegate = self;
//        //[self.serviceBrowser startBrowsingForPeers];
//        
//        self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID discoveryInfo:nil serviceType:self.serviceType];
//        self.serviceAdvertiser.delegate = self;
//        //[self.serviceAdvertiser startAdvertisingPeer];
//        
//        self.receivedDataHandler = receivedDataHandler;
//    }
//    return self;
//}

- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler serviceType:(NSString *)serviceType peerID:(NSString *)peerID {
    self = [super init];
    
    if (self) {
        self.serviceType = @"ar-collab";
        self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
        //NSLog(@"%@", self.myPeerID);
        //self.serviceType = serviceType;
        //self.myPeerID = [[MCPeerID alloc] initWithDisplayName:peerID];
        //NSLog(@"[multipeer_session]: service type is %@ and peerID display name is %@", serviceType, peerID);
        
        // TODO: If encryptionPreference is MCEncryptionRequired, the connection state is not connected...
        self.session = [[MCSession alloc] initWithPeer:self.myPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.session.delegate = self;
        
        self.serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.myPeerID serviceType:self.serviceType];
        self.serviceBrowser.delegate = self;
        //[self.serviceBrowser startBrowsingForPeers];
        
        self.serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.myPeerID discoveryInfo:nil serviceType:self.serviceType];
        self.serviceAdvertiser.delegate = self;
        //[self.serviceAdvertiser startAdvertisingPeer];
        
        self.receivedDataHandler = receivedDataHandler;
    }
    
    return self;
}

- (void)sendToAllPeers: (NSData *)data {
    //NSLog(@"[ar_session]: send to all peers.");
    if (self.session.connectedPeers.count == 0) {
        NSLog(@"[multipeer_session]: There is no connected peer.");
        return;
    }
    bool success = [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    if (success) {
        //NSLog(@"Send to all peers successfully.");
    } else {
        NSLog(@"Send to all peers unsuccessfully");
    }
}

- (NSArray<MCPeerID *> *)getConnectedPeers {
    return self.session.connectedPeers;
}

- (void)startBrowsing {
    self.isHost = true;
    [self.serviceBrowser startBrowsingForPeers];
}

- (void)startAdvertising {
    self.isHost = false;
    [self.serviceAdvertiser startAdvertisingPeer];
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateConnected) {
        NSLog(@"[multipeer_session]: peer %@ has been connected.", peerID.displayName);
        unsigned long peerId = [[NSNumber numberWithInteger:[peerID.displayName integerValue]] unsignedLongValue];
        MultipeerConnectionStartedForMLAPIDelegate(peerId);
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSLog(@"[multipeer_session]: did receive data from peer %@", peerID.displayName);
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
    NSLog(@"[multipeer_session]: did receive an invitation from peer %@", peerID.displayName);
    invitationHandler(true, self.session);
    // TODO: notify MLAPI
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[multipeer_session]: did find peer %@", peerID.displayName);
    // Invite the found peer into my MCSession.
    [browser invitePeer:peerID toSession:self.session withContext:nil timeout:10];
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    
}

@end

//extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
//UnityHoloKit_SetMultipeerConnectionStartedForMLAPIDelegate(MultipeerConnectionStartedForMLAPI callback) {
//    MultipeerConnectionStartedForMLAPIDelegate = callback;
//}
