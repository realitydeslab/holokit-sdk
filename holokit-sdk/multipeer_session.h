//
//  MultipeerSession.h
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MultipeerSession : NSObject

@property (assign) bool isHost;
// TODO: Change this to a dictionary for faster indexing through client Id.
@property (nonatomic, strong, nullable) NSMutableArray<MCPeerID *> *connectedPeersForMLAPI;
@property (assign) double lastPingTime;
@property (nonatomic, strong, nullable) NSMutableDictionary<MCPeerID *, NSOutputStream *> *outputStreams;

- (instancetype)initWithReceivedDataHandler:(void (^)(NSData *, MCPeerID *))receivedDataHandler serviceType:(NSString *)serviceType peerID:(NSString *)peerID;
- (NSArray<MCPeerID *> *)getConnectedPeers;
- (void)sendToAllPeers:(NSData *)data mode:(MCSessionSendDataMode)mode;
- (void)sendToPeer:(NSData *)data peer:(MCPeerID *)peerId mode:(MCSessionSendDataMode)mode;
- (void)startBrowsing;
- (void)startAdvertising;
- (void)disconnect;
+ (MCSessionSendDataMode)convertMLAPINetworkChannelToSendDataMode:(int)channel;

@end

@interface InputStreamForMLAPI : NSObject <NSStreamDelegate>

@property (nonatomic, strong) MultipeerSession *multipeerSession;
@property (nonatomic, strong) MCPeerID *peerID;

- (instancetype)initWithMultipeerSession:(MultipeerSession *)multipeerSession peerID:(MCPeerID *)peerID;

@end
