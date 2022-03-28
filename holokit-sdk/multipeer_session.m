//
//  MultipeerSession.m
//  ARCollaborationDOE
//
//  Created by Yuchen on 2021/4/25.
//

#import "multipeer_session.h"
#import "IUnityInterface.h"
#import "ar_session.h"

typedef void (*BrowserDidFindPeer)(unsigned long transportId, const char *deviceName);
BrowserDidFindPeer BrowserDidFindPeerDelegate = NULL;

typedef void (*BrowserDidLosePeer)(unsigned long transportId);
BrowserDidLosePeer BrowserDidLosePeerDelegate = NULL;

typedef void (*DidReceiveARWorldMap)(void);
DidReceiveARWorldMap DidReceiveARWorldMapDelegate = NULL;

typedef void (*DidReceiveHostLocalIpAddress)(const char *ip);
DidReceiveHostLocalIpAddress DidReceiveHostLocalIpAddressDelegate = NULL;

typedef void (*DidReceivePhotonRoomName)(const char *roomName);
DidReceivePhotonRoomName DidReceivePhotonRoomNameDelegate = NULL;

typedef enum {
    NetcodeTransportPhoton = 0,
    NetcodeTransportWifi = 1,
} NetcodeTransport;

@interface MultipeerSession () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) MCPeerID *localPeerID;
@property (nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSMutableArray<MCPeerID *> *browsedPeers;
@property (assign) NetcodeTransport netcodeTransport;
@property (nonatomic, strong) NSString *hostLocalIpAddress;
@property (nonatomic, strong) NSString *photonRoomName;

@end

@implementation MultipeerSession

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

+ (id _Nonnull)sharedMultipeerSession {
    static dispatch_once_t onceToken = 0;
    static id _sharedObject = nil;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)initializeWithServiceType:(NSString *)serviceType {
    self.serviceType = serviceType;
    // Hash device name and current system uptime to get a random transportId
    NSString *deviceName = [UIDevice currentDevice].name;
    NSString *systemUptime = [[NSNumber numberWithDouble:[[NSProcessInfo processInfo] systemUptime]] stringValue];
    NSString *str = [NSString stringWithFormat:@"%@%@", deviceName, systemUptime];
    unsigned long hashedNumber = [str hash];
    NSString *displayName = [NSString stringWithFormat:@"%lu", hashedNumber];
    // Optional: To prevent the overflow problem when marshalling although it is unlikely to happen.
    displayName = [displayName substringToIndex:11];
    NSLog(@"[mc_session] initialized MultipeerSession with peerID: %@", displayName);
    self.localPeerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    
    // Initialize the mcSession
    self.mcSession = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    self.mcSession.delegate = self;
}

- (void)sendToAllPeers: (NSData *)data sendDataMode:(MCSessionSendDataMode)sendDataMode {
    bool success = [self.mcSession sendData:data toPeers:self.mcSession.connectedPeers withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[multipeer_session] Failed to send data to all peers");
    }
}

- (void)startBrowsing {
    self.browsedPeers = [[NSMutableArray alloc] init];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:self.serviceType];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
    NSLog(@"[mc_session] started browsing");
}

- (void)stopBrowsing {
    [self.browser stopBrowsingForPeers];
    self.browser = nil;
    NSLog(@"[mc_session] stopped browsing");
}

- (void)startAdvertising {
    // Note: If we want password, add it here.
    NSDictionary<NSString *, NSString *> *discoveryInfo = @{ @"DeviceName":[[UIDevice currentDevice] name] };
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:discoveryInfo serviceType:self.serviceType];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
    NSLog(@"[mc_session] started advertising");
}

- (void)stopAdvertising {
    [self.advertiser stopAdvertisingPeer];
    self.advertiser = nil;
    NSLog(@"[mc_session] stopped advertising");
}

- (bool)isHost {
    if (self.advertiser != nil) {
        return YES;
    } else {
        return NO;
    }
}

- (void)sendToPeer: (NSData *)data peer:(MCPeerID *)peerID sendDataMode:(MCSessionSendDataMode)sendDataMode {
    NSArray *peerArray = @[peerID];
    bool success = [self.mcSession sendData:data toPeers:peerArray withMode:sendDataMode error:nil];
    if (!success) {
        NSLog(@"[mc_session] failed to send data to peer %@", peerID.displayName);
    }
}

+ (NSNumber *)convertNSString2NSNumber:(NSString *)str {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter numberFromString:str];
}

- (void)invitePeer:(MCPeerID *)peerID {
    NSDictionary<NSString *, NSString *> *dict = @{ @"DeviceName":[[UIDevice currentDevice] name], @"Password":@"" };
    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:NO error:nil];
    [self.browser invitePeer:peerID toSession:self.mcSession withContext:context timeout:30];
}

- (void)sendPhotonRoomName2Peer:(MCPeerID *)peerID {
    const char *str = [self.photonRoomName cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 0;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
    free(data);
}

- (void)sendHostLocalIpAddress2Peer:(MCPeerID *)peerID {
    const char *str = [self.hostLocalIpAddress cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char *data = malloc(2 + strlen(str));
    data[0] = 1;
    data[1] = strlen(str);
    memcpy(data + 2, str, strlen(str));
    NSData *dataReadyToBeSent = [NSData dataWithBytes:data length:(2 + strlen(str))];
    [self sendToPeer:dataReadyToBeSent peer:peerID sendDataMode:MCSessionSendDataReliable];
    free(data);
}

- (void)sendARWorldMap:(MCPeerID *)peerID {
    NSLog(@"[world map] send ARWorldMap to %@", peerID.displayName);
    ARWorldMap *worldMap = [[ARSessionDelegateController sharedARSessionDelegateController] worldMap];
    NSData *mapData = [NSKeyedArchiver archivedDataWithRootObject:worldMap requiringSecureCoding:NO error:nil];
    [self sendToPeer:mapData peer:peerID sendDataMode:MCSessionSendDataReliable];
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nullable))invitationHandler {
    NSLog(@"[mc_session] did receive invitation from peer %@", [peerID displayName]);
    invitationHandler(true, self.mcSession);
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary<NSString *,NSString *> *)info {
    NSLog(@"[mc_session] found peer %@", peerID.displayName);
    [self.browsedPeers addObject:peerID];
    
    NSString *deviceName = info[@"DeviceName"];
    NSNumber *transportId = [MultipeerSession convertNSString2NSNumber:peerID.displayName];
    if (BrowserDidFindPeerDelegate) {
        BrowserDidFindPeerDelegate([transportId unsignedLongValue], [deviceName UTF8String]);
    }
}

- (void)browser:(nonnull MCNearbyServiceBrowser *)browser lostPeer:(nonnull MCPeerID *)peerID {
    NSLog(@"[mc_session] lost peer %@", peerID.displayName);
    [self.browsedPeers removeObject:peerID];
    if (BrowserDidLosePeerDelegate) {
        BrowserDidLosePeerDelegate([[MultipeerSession convertNSString2NSNumber:peerID.displayName] unsignedLongValue]);
    }
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch(state) {
        case MCSessionStateConnecting: {
            NSLog(@"[mc_session] connecting with peer %@", peerID.displayName);
            break;
        }
        case MCSessionStateConnected: {
            NSLog(@"[mc_session] connected with peer %@", peerID.displayName);
            if ([self isHost]) {
                switch(self.netcodeTransport) {
                    case NetcodeTransportWifi:
                        [self sendHostLocalIpAddress2Peer:peerID];
                        break;
                    case NetcodeTransportPhoton:
                        [self sendPhotonRoomName2Peer:peerID];
                        break;
                }
                [self sendARWorldMap:peerID];
            } else {
                //[self stopBrowsing];
            }
            break;
        }
        case MCSessionStateNotConnected: {
            NSLog(@"[mc_session] disconnected with peer %@", peerID.displayName);
            break;
        }
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    unsigned char *decodedData = (unsigned char *) [data bytes];
    switch ((int)decodedData[0]) {
        case 0: {
            // Photon room name
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *photonRoomName = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            free(str);
            if (DidReceivePhotonRoomNameDelegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DidReceivePhotonRoomNameDelegate([photonRoomName UTF8String]);
                });
            }
            break;
        }
        case 1: {
            // Host local ip address
            int strlen = (int)decodedData[1];
            char *str = malloc(strlen);
            memcpy(str, decodedData + 2, strlen);
            NSString *hostLocalIpAddress = [[NSString alloc] initWithBytes:str length:strlen encoding:NSUTF8StringEncoding];
            free(str);
            if (DidReceiveHostLocalIpAddressDelegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DidReceiveHostLocalIpAddressDelegate([hostLocalIpAddress UTF8String]);
                });
            }
            break;
        }
        default: {
            ARWorldMap *worldMap = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARWorldMap class] fromData:data error:nil];
            if (worldMap != nil) {
                NSLog(@"[world_map] did receive ARWorldMap of size %f mb", data.length / 1024.0 / 1024.0);
                [[ARSessionDelegateController sharedARSessionDelegateController] setWorldMap:worldMap];
                if (DidReceiveARWorldMapDelegate) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DidReceiveARWorldMapDelegate();
                    });
                }
            }
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

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler {
    certificateHandler(YES);
}

@end

#pragma mark - extern "C"

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCInitialize(const char* serviceType) {
    MultipeerSession* mc_session = [MultipeerSession sharedMultipeerSession];
    [mc_session initializeWithServiceType:[NSString stringWithUTF8String:serviceType]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStartBrowsing(void) {
    [[MultipeerSession sharedMultipeerSession] startBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStartAdvertising(void) {
    [[MultipeerSession sharedMultipeerSession] startAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStopBrowsing(void) {
    [[MultipeerSession sharedMultipeerSession] stopBrowsing];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCStopAdvertising(void) {
    [[MultipeerSession sharedMultipeerSession] stopAdvertising];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCDeinitialize(void) {
    MultipeerSession *multipeerSession = [MultipeerSession sharedMultipeerSession];
    if ([[multipeerSession.mcSession connectedPeers] count] > 0)
        [multipeerSession.mcSession disconnect];
    [multipeerSession setMcSession:nil];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetBrowserDidFindPeerDelegate(BrowserDidFindPeer callback) {
    BrowserDidFindPeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetBrowserDidLosePeerDelegate(BrowserDidLosePeer callback) {
    BrowserDidLosePeerDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCInvitePeer(unsigned long transportId) {
    MultipeerSession *multipeerSession = [MultipeerSession sharedMultipeerSession];
    for (MCPeerID *peerID in multipeerSession.browsedPeers) {
        if (transportId == [[MultipeerSession convertNSString2NSNumber:peerID.displayName] unsignedLongValue]) {
            [multipeerSession invitePeer:peerID];
        }
    }
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetPhotonRoomName(const char *roomName) {
    MultipeerSession *session = [MultipeerSession sharedMultipeerSession];
    [session setPhotonRoomName:[NSString stringWithUTF8String:roomName]];
    [session setNetcodeTransport:NetcodeTransportPhoton];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetHostLocalIpAddress(const char *ip) {
    //[[[ARSessionDelegateController sharedARSessionDelegateController] multipeerSession] setHostLocalIpAddress:[NSString stringWithUTF8String:ip]];
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetDidReceivePhotonRoomNameDelegate(DidReceivePhotonRoomName callback) {
    DidReceivePhotonRoomNameDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetDidReceiveHostLocalIpAddressDelegate(DidReceiveHostLocalIpAddress callback) {
    DidReceiveHostLocalIpAddressDelegate = callback;
}

void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCSetDidReceiveARWorldMapDelegate(DidReceiveARWorldMap callback) {
    DidReceiveARWorldMapDelegate = callback;
}

bool UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API
UnityHoloKit_MPCIsHost(void) {
    return [[MultipeerSession sharedMultipeerSession] isHost];
}
