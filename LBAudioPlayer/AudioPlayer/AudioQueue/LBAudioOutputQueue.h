//
//  LBAudioOutputQueue.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/* 音频队列管理 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef void (^LBAudioOutputQueueBlock) (BOOL waitting);

@interface LBAudioOutputQueue : NSObject

@property (nonatomic, copy) LBAudioOutputQueueBlock audioQueueBlock;

@property (readonly) BOOL isAvailable;

@property (readonly) BOOL isRunning;

@property (nonatomic, readonly) NSTimeInterval playedTime;

@property (nonatomic, assign) float volume;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format
                    bufferSize:(UInt32)bufferSize
                  macgicCookie:(NSData *)macgicCookie;

- (BOOL)playWithParsedData:(NSData *)data
               packetCount:(UInt32)packetCount
        packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions
                     isEOF:(BOOL)isEOF;
- (BOOL)playWithParsedBytes:(void const *)bytes
                     length:(NSUInteger)length
                packetCount:(UInt32)packetCount
         packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions
                      isEOF:(BOOL)isEOF;

- (BOOL)start;

- (BOOL)pause;

- (BOOL)resume;

- (BOOL)stop:(BOOL)immediately;

- (BOOL)reset;

- (BOOL)flush;

@end
