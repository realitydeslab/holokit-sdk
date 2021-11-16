//
//  multipeer_session.h
//  holokit
//
//  Created by Yuchen on 2021/4/25.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

NS_ASSUME_NONNULL_BEGIN
@interface MultipeerSession: NSObject

@property (nonatomic, strong, nullable) NSMutableArray<MCPeerID *> *connectedPeersForUnity;
@property (assign) double lastPingTime;

- (instancetype)initWithServiceType:(NSString *)serviceType;
- (void)sendToAllPeers:(NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode;
- (void)sendToPeer:(NSData *)data peer:(MCPeerID *)peerId sendDataMode:(MCSessionSendDataMode)sendDataMode;
- (bool)isHost;

+ (MCSessionSendDataMode)convertMLAPINetworkChannelToSendDataMode:(int)channel;

@end
NS_ASSUME_NONNULL_END
