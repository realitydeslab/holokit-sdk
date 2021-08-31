//
//  watch_connectivity.h
//  watch_connectivity
//
//  Created by Yuchen on 2021/8/30.
//

#ifndef watch_connectivity_h
#define watch_connectivity_h

#import <WatchConnectivity/WatchConnectivity.h>

@interface HoloKitWatchConnectivity: NSObject

- (void)close;

+ (id)getSingletonInstance;

@end

#endif /* watch_connectivity_h */
