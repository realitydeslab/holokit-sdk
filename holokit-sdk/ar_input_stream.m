//
//  ARInputStream.m
//  holokit-sdk
//
//  Created by Yuchen Zhang on 2021/12/14.
//

#import "ar_input_stream.h"
#import "ar_session_manager.h"

@interface ARInputStream() 

@property (nonatomic, strong) NSInputStream *inputStream;

@end

@implementation ARInputStream

- (instancetype)initWithInputStream:(NSInputStream *)inputStream {
    self = [super init];
    if (self) {
        self.inputStream = inputStream;
    }
    return self;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSLog(@"[ar_input_stream] did receive input stream data");
    if (eventCode == NSStreamEventHasBytesAvailable) {
        uint8_t *buffer = malloc(65536 * sizeof(uint8_t));
        NSUInteger length = [self.inputStream read:buffer maxLength:65536];
        NSLog(@"[ar_input_stream] data length %lu", length);
        NSData *data = [NSData dataWithBytes:buffer length:length];
        free(buffer);
//
//        ARCollaborationData* collaborationData = [NSKeyedUnarchiver unarchivedObjectOfClass:[ARCollaborationData class] fromData:data error:nil];
//        if (collaborationData != nil) {
//            [[HoloKitARSession sharedARSession] updateWithCollaborationData:collaborationData];
//            return;
//        }
    }
}

@end
