//
//  LBAudioOutputQueue.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioOutputQueue.h"
#import <pthread.h>
#import "LBAudioDefine.h"

@interface LBAudioOutputQueue (){
    AudioQueueRef audioQueue;                //音频队列
    
    AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];  // audio queue buffers
    
    AudioStreamBasicDescription audioFormat;  //An audio data format specification for a stream of audio
    
    UInt32 audioBufferSize;                   //定义一个buffer的大小
    
    bool inUseBuffer[kNumAQBufs];             //用来标记buffer使用状态
    
    pthread_mutex_t mutex;
	pthread_cond_t cond;
}

@property (nonatomic, assign) NSTimeInterval playedTime;

@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, assign) NSUInteger currentFillBufferIndex;

@property (nonatomic, assign) BOOL hasStart;

@property (nonatomic, assign) BOOL isEOF;

@property (nonatomic, assign) NSInteger bufferUsed;

- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer;

- (void)handleIsRunningPropertyChangeForQueue:(AudioQueueRef)inAQ
                                   propertyID:(AudioQueuePropertyID)inID;

@end

//每播放完一个buffer则回调一次
static void LBAudioQueueOutputCallback(void*				inClientData,
                                       AudioQueueRef			inAQ,
                                       AudioQueueBufferRef		inBuffer){
	LBAudioOutputQueue* audioOutputQueue = (__bridge LBAudioOutputQueue *)inClientData;
	[audioOutputQueue handleBufferCompleteForQueue:inAQ
                                            buffer:inBuffer];
}

//检测isRuning属性
static void LBAudioQueueIsRunningCallback(void *inUserData,
                                          AudioQueueRef inAQ,
                                          AudioQueuePropertyID inID){
	LBAudioOutputQueue* audioOutputQueue = (__bridge LBAudioOutputQueue *)inUserData;
	[audioOutputQueue handleIsRunningPropertyChangeForQueue:inAQ
                                                 propertyID:inID];
}


@implementation LBAudioOutputQueue

#pragma mark -
#pragma mark  Accessor

- (float)volume{
    float volume;
    OSStatus status = AudioQueueGetParameter(audioQueue,
                                             kAudioQueueParam_Volume,
                                             &volume);
    if (status != noErr) {
        NSLog(@"getVolume Error");
    }
    return volume;
}

- (void)setVolume:(float)volume{
    OSStatus status = AudioQueueSetParameter (audioQueue,
                                              kAudioQueueParam_Volume,
                                              volume
                                              );
    if (status != noErr) {
        NSLog(@"setVolume Error");
    }
}

- (NSTimeInterval)playedTime{
    if (audioFormat.mSampleRate == 0){
        return 0;
    }
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(audioQueue, NULL, &time, NULL);
    if (status == noErr){
        _playedTime = time.mSampleTime / audioFormat.mSampleRate;
    }
    return _playedTime;
}

#pragma mark -
#pragma mark   Life

- (void)dealloc{
    [self mutexDestory];
    [self disposeAudioQueue];
}

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format
                    bufferSize:(UInt32)bufferSize
                  macgicCookie:(NSData *)macgicCookie{
    self = [super init];
    if (self) {
        audioFormat = format;
        audioBufferSize = bufferSize;
        self.currentFillBufferIndex = 0;
        [self creatAudioQueue:macgicCookie];
        [self mutexInit];
    }
    return self;
}


#pragma mark -
#pragma mark  Public Method

- (BOOL)isAvailable{
    return audioQueue != NULL;
}

- (BOOL)playWithParsedData:(NSData *)data
               packetCount:(UInt32)packetCount
        packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions
                     isEOF:(BOOL)isEOF{
    self.isEOF = isEOF;
    
    //标记当前使用的buffer
    inUseBuffer[self.currentFillBufferIndex] = true;
    self.bufferUsed ++;
//    NSLog(@"playWithParsedData: %ld",(long)self.bufferUsed);

    //给当前使用的buffer填充数据
    AudioQueueBufferRef buffer = audioQueueBuffer[self.currentFillBufferIndex];
    memcpy(buffer->mAudioData, [data bytes], [data length]);
    buffer->mAudioDataByteSize = (UInt32)[data length];
    
    //填充到AudioQueue
    OSStatus status = AudioQueueEnqueueBuffer(audioQueue,
                                              buffer,
                                              packetCount,
                                              packetDescriptions);
    if (status == noErr){
        if (!self.hasStart && ((self.bufferUsed >= kNumAQBufs - 1) || isEOF)) {
            if (self.audioQueueBlock) {
                self.audioQueueBlock(NO);
            }
            [self start];
        }
    }
    
    //循环使用1-2-3-1
    if (++self.currentFillBufferIndex >= kNumAQBufs) {
        self.currentFillBufferIndex = 0;
    }
    
    //等待buffer
    while (inUseBuffer[self.currentFillBufferIndex]) {
        [self mutexWait];
    }
    
    return status == noErr;
}

- (BOOL)start{
    if (self.hasStart) {
        return YES;
    }
    OSStatus status = AudioQueueStart(audioQueue, NULL);
    self.hasStart = status == noErr;
    return self.hasStart;
}

- (BOOL)pause{
    OSStatus status = AudioQueuePause(audioQueue);
    self.hasStart = NO;
    return status == noErr;
}

- (BOOL)resume{
    OSStatus status = AudioQueueReset(audioQueue);
    return status == noErr;
}

- (BOOL)stop:(BOOL)immediately{
    OSStatus status = noErr;
    if (immediately){
        status = AudioQueueStop(audioQueue, true);
    } else {
        status = AudioQueueStop(audioQueue, false);
    }
    self.hasStart = NO;
    self.playedTime = 0;
    return status == noErr;
}

- (BOOL)reset{
    OSStatus status = AudioQueueReset(audioQueue);
    return status == noErr;
}

- (BOOL)flush{
    OSStatus status = AudioQueueFlush(audioQueue);
    return status == noErr;
}

#pragma mark -
#pragma mark  private Methods

#pragma mark -
#pragma mark     AudioQueue create & dispose

/* 创建音频队列 */
- (void)creatAudioQueue:(NSData *)macgicCookie{
    //创建一个audioQueue
    OSStatus status = AudioQueueNewOutput(&audioFormat,
                                          LBAudioQueueOutputCallback,
                                          (__bridge void *)(self),
                                          NULL,
                                          NULL,
                                          0,
                                          &audioQueue);
    if (status != noErr) {
        
        return;
    }
    
    //监听 "isRunning" 属性
    status = AudioQueueAddPropertyListener(audioQueue,
                                           kAudioQueueProperty_IsRunning,
                                           LBAudioQueueIsRunningCallback,
                                           (__bridge void *)(self));
    if (status != noErr) {
        
        return;
    }
    
    //初始化audioQueueBuffers
	for (unsigned int i = 0; i < kNumAQBufs; ++i){
		status = AudioQueueAllocateBuffer(audioQueue,
                                          audioBufferSize,
                                          &audioQueueBuffer[i]);
		if (status != noErr){
            
			return;
		}
	}
    
#if TARGET_OS_IPHONE
    // set the software codec too on the queue.
    UInt32 val = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    OSStatus ignorableError = AudioQueueSetProperty(audioQueue,
                                                    kAudioQueueProperty_HardwareCodecPolicy,
                                                    &val,
                                                    sizeof(UInt32));
    if (ignorableError != noErr){
        
        return;
    }
#endif
    if (macgicCookie){
        AudioQueueSetProperty(audioQueue,
                              kAudioQueueProperty_MagicCookie,
                              [macgicCookie bytes],
                              (UInt32)[macgicCookie length]);
    }
}

- (void)disposeAudioQueue{
    if (audioQueue != NULL){
        AudioQueueDispose(audioQueue,true);
        audioQueue = NULL;
    }
}

#pragma mark -
#pragma mark     mutexLock

- (void)mutexInit{
    pthread_mutex_init(&mutex, NULL);
    pthread_cond_init(&cond, NULL);
}

- (void)mutexDestory{
    pthread_mutex_destroy(&mutex);
    pthread_cond_destroy(&cond);
}

- (void)mutexWait{
    pthread_mutex_lock(&mutex);
    pthread_cond_wait(&cond, &mutex);
    pthread_mutex_unlock(&mutex);
}

- (void)mutexSignal{
    pthread_mutex_lock(&mutex);
    pthread_cond_signal(&cond);
    pthread_mutex_unlock(&mutex);
}

#pragma mark -
#pragma mark    AudioQueue callbacl implementation

- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer{
    NSUInteger completeIndex = -1;
    for (int i = 0; i < kNumAQBufs; i++) {
        if(audioQueueBuffer[i] == inBuffer){
            completeIndex = i;
        }
    }
    
    if (completeIndex == -1) {
        NSLog(@"handleBufferCompleteForQueue  Not Found audioQueueBuffer");
    } else {
        inUseBuffer[completeIndex] = false;
        self.bufferUsed--;
//        NSLog(@"handleBufferCompleteForQueue: %ld",(long)self.bufferUsed);
        if (self.bufferUsed == 0 && !self.isEOF) {
            if (self.audioQueueBlock) {
                self.audioQueueBlock(YES);
            }
            [self pause];
        }
    }
    [self mutexSignal];
}


- (void)handleIsRunningPropertyChangeForQueue:(AudioQueueRef)inAQ
                                   propertyID:(AudioQueuePropertyID)inID{
    if (inID == kAudioQueueProperty_IsRunning) {
        // A nonzero value means running; 0 means stopped
        UInt32 isRunning = 0;
        UInt32 size = sizeof(UInt32);
        AudioQueueGetProperty(audioQueue, inID, &isRunning, &size);
        self.isRunning = isRunning;
        NSLog(@"handleIsRunningPropertyChangeForQueue %d",(unsigned int)isRunning);
    }
}

@end
