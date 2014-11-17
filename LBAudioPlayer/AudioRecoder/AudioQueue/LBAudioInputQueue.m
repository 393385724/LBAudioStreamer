//
//  LBAudioInputQueue.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioInputQueue.h"
#import "LBAudioDefine.h"

const Float64 kBufferDurationSeconds = 0.5;
const int kNumAQInPutBufs = 3;

@interface LBAudioInputQueue (){
    AudioQueueRef               audioQueue;
    AudioQueueBufferRef         audioQueueBuffer[kNumAQInPutBufs];
    AudioStreamBasicDescription audioFormat;
    AudioQueueLevelMeterState   *levelMeters;
}

@property (nonatomic, assign) BOOL hasStart;

@property (nonatomic, assign) NSTimeInterval recoderTime;


- (void)handleIsRunningPropertyChangeForQueue:(AudioQueueRef)inAQ
                                   propertyID:(AudioQueuePropertyID)inID;

@end

#pragma mark -
#pragma mark    AudioQueue callbacl

//每填充一个buffer回调掉一次
static void LBAudioQueueInputCallback(void *                          inUserData,
                                      AudioQueueRef                   inAQ,
                                      AudioQueueBufferRef             inBuffer,
                                      const AudioTimeStamp *          inStartTime,
                                      UInt32                          inNumberPacketDescriptions,
                                      const AudioStreamPacketDescription *inPacketDescs){
    LBAudioInputQueue *audioInputQueue = (__bridge LBAudioInputQueue *)inUserData;
    if (audioInputQueue.hasStart) {
        BOOL success = YES;
        if (audioInputQueue.delegate && [audioInputQueue.delegate respondsToSelector:@selector(handleBufferFillingCompleteBuffer:startTime:NumberPacketDescriptions:PacketDescs:)]) {
           success = [audioInputQueue.delegate handleBufferFillingCompleteBuffer:inBuffer startTime:inStartTime NumberPacketDescriptions:inNumberPacketDescriptions PacketDescs:inPacketDescs];
        }
        if (success && audioInputQueue.hasStart) {
            OSStatus status = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
            if (status != noErr) {
                LBLog(@"AudioQueueEnqueueBuffer:%@",OSStatusCode(status));
            }
        }
    }
}

//检测isRuning属性
static void LBAudioQueueIsRunningCallback(void *inUserData,
                                          AudioQueueRef inAQ,
                                          AudioQueuePropertyID inID){
    LBAudioInputQueue* audioInputQueue = (__bridge LBAudioInputQueue *)inUserData;
    [audioInputQueue handleIsRunningPropertyChangeForQueue:inAQ
                                                 propertyID:inID];
}


@implementation LBAudioInputQueue

#pragma mark -
#pragma mark  Accessor

- (NSTimeInterval)recoderTime{
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(audioQueue, NULL, &time, NULL);
    if (status == noErr){
        _recoderTime = time.mSampleTime / audioFormat.mSampleRate;
    }
    return _recoderTime;
}

- (BOOL)isMeteringEnabled{
    UInt32 val = 0;
    UInt32 valSize = sizeof(val);
    OSStatus status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_EnableLevelMetering, &val, &valSize);
    if (status != noErr) {
        LBLog(@"AudioQueueLevelMeterState SET: %@",OSStatusCode(status));
        return NO;
    }
    return val;
}

-(void)setMeteringEnabled:(BOOL)meteringEnabled{
    OSStatus status = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_EnableLevelMetering, &meteringEnabled, sizeof(UInt32));
    if (status != noErr) {
        LBLog(@"AudioQueueLevelMeterState SET: %@",OSStatusCode(status));
    }
}

- (void)updateMeters{
    UInt32 propertySize = sizeof(AudioQueueLevelMeterState) * audioFormat.mChannelsPerFrame;
    OSStatus status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_CurrentLevelMeterDB, levelMeters, &propertySize);
    if (status != noErr) {
        LBLog(@"kAudioQueueProperty_CurrentLevelMeterDB SET: %@",OSStatusCode(status));
    }
}

- (float)peakPowerForChannel:(NSUInteger)channelNumber{
    return levelMeters[channelNumber].mPeakPower;
}

- (float)averagePowerForChannel:(NSUInteger)channelNumber{
    return levelMeters[channelNumber].mAveragePower;
}

#pragma mark -
#pragma mark  Life Cycle

- (void)dealloc{
    free(levelMeters);
}

- (instancetype) initWithFormat:(AudioStreamBasicDescription)recoderFormat{
    self = [super init];
    if (self) {
        audioFormat = recoderFormat;
        [self creatAudioQueue];
    }
    return self;
}

- (BOOL)start{
    if (self.hasStart) {
        return YES;
    }
    OSStatus status = AudioQueueStart(audioQueue, NULL);
    if (status != noErr) {
        LBLog(@"AudioQueueStart: %@",OSStatusCode(status));
    }
    self.hasStart = status == noErr;
    return self.hasStart;
}

- (BOOL)pause{
    OSStatus status = AudioQueuePause(audioQueue);
    if (status != noErr) {
        LBLog(@"AudioQueuePause: %@",OSStatusCode(status));
    }
    self.hasStart = NO;
    return status == noErr;
}

- (BOOL)resume{
    OSStatus status = AudioQueueReset(audioQueue);
    if (status != noErr) {
        LBLog(@"AudioQueueReset: %@",OSStatusCode(status));
    }
    return status == noErr;
}

- (BOOL)stop{
    self.hasStart = NO;
    OSStatus status = AudioQueueStop(audioQueue, true);
    if (status != noErr) {
        LBLog(@"AudioQueueStop: %@",OSStatusCode(status));
    }
    return status == noErr;
}

- (BOOL)reset{
    OSStatus status = AudioQueueReset(audioQueue);
    if (status != noErr) {
        LBLog(@"AudioQueueReset: %@",OSStatusCode(status));
    }
    return status == noErr;
}

- (BOOL)flush{
    OSStatus status = AudioQueueFlush(audioQueue);
    if (status != noErr) {
        LBLog(@"AudioQueueFlush: %@",OSStatusCode(status));
    }
    return status == noErr;
}

#pragma mark -
#pragma mark Private Methods

- (void)creatAudioQueue{
    OSStatus status = AudioQueueNewInput(&audioFormat,
                                         LBAudioQueueInputCallback,
                                         (__bridge void *)(self),
                                         NULL,
                                         kCFRunLoopCommonModes,
                                         0,
                                         &audioQueue);
    if (status != noErr) {
        LBLog(@"AudioQueueNewInput Error:%@",OSStatusCode(status));
        return;
    }
    
    //监听 "isRunning" 属性
    status = AudioQueueAddPropertyListener(audioQueue,
                                           kAudioQueueProperty_IsRunning,
                                           LBAudioQueueIsRunningCallback,
                                           (__bridge void *)(self));
    if (status != noErr) {
        LBLog(@"AudioQueueAddPropertyListener:%@",OSStatusCode(status));
        return;
    }
    
    UInt32 size = sizeof(audioFormat);
    status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_StreamDescription,
                                        &audioFormat, &size);
    if (status != noErr) {
        LBLog(@"AudioQueueGetProperty Error:%@",OSStatusCode(status));
        return;
    }

    UInt32 bufferByteSize = [self computeRecordBufferSize];
    
    //初始化audioQueueBuffers
    for (unsigned int i = 0; i < kNumAQInPutBufs; ++i){
        status = AudioQueueAllocateBuffer(audioQueue,
                                          bufferByteSize,
                                          &audioQueueBuffer[i]);
        if (status != noErr){
            LBLog(@"AudioQueueAllocateBuffer:%@",OSStatusCode(status));
        }
        
        status = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer[i], 0, NULL);
        if (status != noErr) {
            LBLog(@"AudioQueueEnqueueBuffer:%@",OSStatusCode(status));
        }
    }
    
    levelMeters = (AudioQueueLevelMeterState *)malloc(sizeof(AudioQueueLevelMeterState) * audioFormat.mChannelsPerFrame);
    memset(levelMeters, 0, sizeof(AudioQueueLevelMeterState) * audioFormat.mChannelsPerFrame);
}

- (BOOL)copyEncoderCookie:(NSData **)data size:(UInt32 *)magicCookieSize{
    UInt32 propertySize;
    // get the magic cookie, if any, from the converter
    OSStatus status = AudioQueueGetPropertySize(audioQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    
    // we can get a noErr result and also a propertySize == 0
    // -- if the file format does support magic cookies, but this file doesn't have one.
    if (status == noErr && propertySize > 0) {
        Byte *magicCookie = malloc(propertySize);
        status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize);
        if (status != noErr) {
            free(magicCookie);
            LBLog(@"AudioQueueGetProperty %@",OSStatusCode(status));
            return NO;
        }
        *magicCookieSize = propertySize;	// the converter lies and tell us the wrong size
        *data = [NSData dataWithBytes:magicCookie length:propertySize];
        free(magicCookie);
        return YES;
    }
    return NO;
}

- (UInt32)computeRecordBufferSize{
    UInt32 packets, frames, bytes = 0;
    //计算seconds中包含帧的个数
    frames = (UInt32)ceil(kBufferDurationSeconds * audioFormat.mSampleRate);
    if (audioFormat.mBytesPerFrame > 0){
        bytes = frames * audioFormat.mBytesPerFrame;
    } else {
        UInt32 maxPacketSize;
        if (audioFormat.mBytesPerPacket > 0){
            maxPacketSize = audioFormat.mBytesPerPacket;	// constant packet size
        } else {
            UInt32 propertySize = sizeof(maxPacketSize);
            OSStatus status = AudioQueueGetProperty(audioQueue,
                                                    kAudioQueueProperty_MaximumOutputPacketSize,
                                                    &maxPacketSize,
                                                    &propertySize);
            if (status != noErr) {
                LBLog(@"AudioQueueGetProperty: %@",OSStatusCode(status));
                return 0;
            }
        }
        if (audioFormat.mFramesPerPacket > 0){
            packets = frames / audioFormat.mFramesPerPacket;
        } else {
            packets = frames;	// worst-case scenario: 1 frame in a packet
        }
        if (packets == 0){		// sanity check
            packets = 1;
        }
        bytes = packets * maxPacketSize;
    }
    return bytes;
}

#pragma mark -
#pragma mark    AudioQueue callbacl implementation

- (void)handleIsRunningPropertyChangeForQueue:(AudioQueueRef)inAQ
                                   propertyID:(AudioQueuePropertyID)inID{
    if (inID == kAudioQueueProperty_IsRunning) {
        // A nonzero value means running; 0 means stopped
        UInt32 isRunning = 0;
        UInt32 size = sizeof(UInt32);
        OSStatus status = AudioQueueGetProperty(audioQueue, inID, &isRunning, &size);
        if (status != noErr) {
            LBLog(@"kAudioQueueProperty_IsRunning Error");
        }
        self.isRunning = isRunning;
        LBLog(@"handleIsRunningPropertyChangeForQueue %d",(unsigned int)isRunning);
    }
}


@end
