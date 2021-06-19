//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"

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
        NSLog(@"%@", self.myPeerID);
        
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

- (void)sendToAllPeers: (NSData *)data {
    if (self.session.connectedPeers.count == 0) {
        NSLog(@"There is zero connected peer.");
        return;
    }
    bool success = [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    if (success) {
        //NSLog(@"Send to all peers successfully.");
    } else {
        NSLog(@"Send to all peers unsuccessfully");
    }
}

- (NSArray<MCPeerID *> *) GetConnectedPeers {
    return self.session.connectedPeers;
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    NSLog(@"did change state to %d", state);
    
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    //NSLog(@"did receive data delegate");
    self.receivedDataHandler(data, peerID);
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"advertise: receive an invitation.");
    invitationHandler(true, self.session);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"browse: find a peer and invite that device.");
    [browser invitePeer:peerID toSession:self.session withContext:nil timeout:10];
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    
}

@end
