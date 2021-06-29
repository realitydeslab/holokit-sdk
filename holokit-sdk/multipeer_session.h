//
//  MultipeerSession.h
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MultipeerSession : NSObject

@property (assign) bool isHost;

- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler;
- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler serviceType:(NSString *)serviceType peerID:(NSString *)peerID;
- (NSArray<MCPeerID *> *)getConnectedPeers;
- (void)sendToAllPeers: (NSData *)data;
- (void)startBrowsing;
- (void)startAdvertising;

@end
