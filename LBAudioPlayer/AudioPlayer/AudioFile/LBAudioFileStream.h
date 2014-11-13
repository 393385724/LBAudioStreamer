//
//  LBAudioFileStream.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/* 流媒体解析管理 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class LBAudioFileStream;

typedef void (^LBAudioFileStreamBlock) (LBAudioFileStream *fileStream, NSArray *audioDataArray);

@interface LBAudioFileStream : NSObject

@property (nonatomic, copy) LBAudioFileStreamBlock audioFileParsedBlock;

@property (nonatomic,readonly) BOOL readyToProducePackets;

@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic,readonly) AudioStreamBasicDescription format;
@property (nonatomic,readonly) NSTimeInterval duration;
@property (nonatomic,readonly) UInt32 bitRate;
@property (nonatomic,readonly) UInt64 audioDataByteCount;
@property (nonatomic,readonly) SInt64 dataOffset;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType
                           error:(NSError **)error;

- (BOOL)parseData:(NSData *)data error:(NSError **)error;

- (NSData *)fetchMagicCookie;

- (SInt64)seekToTime:(NSTimeInterval)time;

- (void)close;

@end