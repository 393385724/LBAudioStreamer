//
//  LBAudioBufferFactory.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/*用来存储解析出来的PCM数据*/

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface LBAudioBufferPool : NSObject

@property (readonly) NSUInteger bufferPoolSize;  //当前缓存池的大小

+ (LBAudioBufferPool *)bufferPool;

- (void)enqueueFromDataArray:(NSArray *)dataArray;

- (BOOL)isEmpty;

- (NSData *)dequeueDataWithSize:(UInt32)bufferSize
                    packetCount:(UInt32 *)packetCount
                   descriptions:(AudioStreamPacketDescription **)descriptions;

- (void)clean;

@end
