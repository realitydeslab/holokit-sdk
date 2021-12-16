//
//  ARInputStream.h
//  holokit
//
//  Created by Yuchen Zhang on 2021/12/14.
//

#ifndef ARInputStream_h
#define ARInputStream_h

#import <Foundation/Foundation.h>

@interface ARInputStream : NSObject <NSStreamDelegate>

- (instancetype) initWithInputStream:(NSInputStream *)inputStream;

@end

#endif /* ARInputStream_h */
