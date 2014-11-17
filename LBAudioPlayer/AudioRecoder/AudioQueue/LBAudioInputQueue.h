//
//  LBAudioInputQueue.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol LBAudioInputQueueDelegate <NSObject>

- (BOOL)handleBufferFillingCompleteBuffer:(AudioQueueBufferRef)inBuffer
                                  startTime:(const AudioTimeStamp *)inStartTime
                   NumberPacketDescriptions:(UInt32)inNumberPacketDescriptions
                                PacketDescs:(const AudioStreamPacketDescription *)inPacketDescs;
@end

@interface LBAudioInputQueue : NSObject

@property (nonatomic, weak) id<LBAudioInputQueueDelegate> delegate;

@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, readonly) NSTimeInterval recoderTime;

/* metering */
@property(getter=isMeteringEnabled) BOOL meteringEnabled; /* turns level metering on or off. default is off. */
- (void)updateMeters; /* call to refresh meter values */
- (float)peakPowerForChannel:(NSUInteger)channelNumber; /* returns peak power in decibels for a given channel */
- (float)averagePowerForChannel:(NSUInteger)channelNumber; /* returns average power in decibels for a given channel */

- (instancetype) initWithFormat:(AudioStreamBasicDescription)recoderFormat;

- (BOOL)copyEncoderCookie:(NSData **)data size:(UInt32 *)magicCookieSize;

- (BOOL)start;

- (BOOL)pause;

- (BOOL)resume;

- (BOOL)stop;

- (BOOL)reset;

- (BOOL)flush;

@end
