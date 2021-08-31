//
//  multipeer_session.h
//  holokit
//
//  Created by Yuchen on 2021/4/25.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

NS_ASSUME_NONNULL_BEGIN
@interface MultipeerSession: NSObject

@property (nonatomic, strong, nullable) NSMutableArray<MCPeerID *> *connectedPeersForMLAPI;
@property (assign) double lastPingTime;

- (instancetype)initWithPeerName:(NSString *)peerName serviceType:(NSString *)serviceType gameName:(NSString *) gameName sessionName:(NSString *) sessionName;
- (void)sendToAllPeers:(NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode;
- (void)sendToPeer:(NSData *)data peer:(MCPeerID *)peerId sendDataMode:(MCSessionSendDataMode)sendDataMode;
- (bool)isHost;

+ (MCSessionSendDataMode)convertMLAPINetworkChannelToSendDataMode:(int)channel;

@end
NS_ASSUME_NONNULL_END
