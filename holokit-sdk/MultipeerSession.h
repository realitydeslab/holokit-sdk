//
//  MultipeerSession.h
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MultipeerSession : NSObject

- (instancetype)initWithReceivedDataHandler: (void (^)(NSData *, MCPeerID *))receivedDataHandler;
- (NSArray<MCPeerID *> *) GetConnectedPeers;
- (void)sendToAllPeers: (NSData *)data;

@end
