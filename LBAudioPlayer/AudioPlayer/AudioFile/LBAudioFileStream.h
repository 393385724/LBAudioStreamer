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

@property (nonatomic,readonly) AudioStreamBasicDescription format;
@property (nonatomic,readonly) NSTimeInterval duration;
@property (nonatomic,readonly) UInt32 bitRate;
@property (nonatomic,readonly) UInt64 audioDataByteCount;
@property (nonatomic,readonly) SInt64 dataOffset;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType
                        audioURL:(NSURL *)url
                       cachePath:(NSString *)filePath
                           error:(NSError **)error;

- (void)parseDataWithLength:(NSInteger)length isEOF:(BOOL *)isEof error:(NSError **)error;

- (NSData *)fetchMagicCookie;

- (void)seekToTime:(NSTimeInterval *)time;

- (void)close;

@end