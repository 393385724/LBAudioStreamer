//
//  LBAudioRecoder.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LBAudioRecoderDelegate;

@interface LBAudioRecoder : NSObject

@property(nonatomic, weak) id<LBAudioRecoderDelegate>delegate;

@property(readonly, getter=isRecording) BOOL recording;

/* Path of the recorded file */
@property(readonly) NSString *path;

/* these settings are fully valid only when prepareToRecord has been called */
@property(readonly) NSDictionary *settings;

/* get the current time of the recording - only valid while recording */
@property(nonatomic, readonly) NSTimeInterval currentTime;

@property(nonatomic, assign) BOOL meteringEnabled; /* turns level metering on or off. default is off. */

@property(nonatomic, readonly) float level;

- (instancetype)initWithFilePath:(NSString *)filePath settings:(NSDictionary *)settings error:(NSError **)outError;

/* creates the file and gets ready to record. happens automatically on record. */
- (BOOL)prepareToRecord;

/* start or resume recording to file. */
- (BOOL)record;

/* record a file of a specified duration. the recorder will stop when it has recorded this length of audio */
- (BOOL)recordForDuration:(NSTimeInterval) duration;

/*to cancel the current recording*/
- (void)rollback;

/* pause recording */
- (void)pause;

/* stops recording. closes the file. */
- (void)stop;

/* delete the recorded file. recorder must be stopped. returns NO on failure. */
- (BOOL)deleteRecording;

@end


@protocol LBAudioRecoderDelegate <NSObject>

@optional

#if TARGET_OS_IPHONE

- (void)audioRecoderBeginInterruption:(LBAudioRecoder *)player;

- (void)audioRecoderEndInterruption:(LBAudioRecoder *)player;

#endif

@end

