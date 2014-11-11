//
//  LBAudioFile.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/5.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class LBAudioFile;

typedef void (^LBAudioFileBlock) (LBAudioFile *audioFile, NSArray *audioDataArray);


@interface LBAudioFile : NSObject

@property (nonatomic, copy) LBAudioFileBlock audioFileParsedBlock;
@property (readonly) AudioStreamBasicDescription format;
@property (readonly) NSTimeInterval duration;
@property (readonly) UInt32 bitRate;
@property (readonly) UInt64 audioDataByteCount;
@property (readonly) SInt64 dataOffset;

- (instancetype)initWithFilePath:(NSString *)filePath
                        fileType:(AudioFileTypeID)fileType
                           error:(NSError **)error;

- (instancetype)initWithAsset:(NSURL *)iPodUrl
                    cachePath:(NSString *)cachePath
                        error:(NSError **)error;

- (void)parseData:(BOOL *)isEof error:(NSError **)error;

- (NSData *)fetchMagicCookie;

- (void)seekToTime:(NSTimeInterval)time;

- (void)close;

@end
