//
//  LBAudioPlayer.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/5.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioPlayer.h"
#import <pthread.h>
#import "LBAudioSession.h"
#import "LBAudioFile.h"
#import "LBAudioFileStream.h"
#import "LBAudioOutputQueue.h"
#import "LBAudioBufferPool.h"
#import "LBAudioStreamCache.h"

#import "NSString+AudioPlayer.h"
#import "LBAudioDefine.h"

NSString *const AudioPlayerStateChangeNotification = @"AudioPlayerStateChangeNotification";

@interface LBAudioPlayer (){
    pthread_mutex_t mutex;
    pthread_cond_t cond;
}

@property (nonatomic, strong) NSThread             *playThread;
@property (nonatomic, strong) LBAudioFile          *audioFile;
@property (nonatomic, strong) LBAudioFileStream    *audioFileStream;
@property (nonatomic, strong) LBAudioStreamCache   *streamCache;
@property (nonatomic, strong) LBAudioOutputQueue   *audioOutputQueue;
@property (nonatomic, strong) LBAudioBufferPool    *audioBufferPool;
@property (nonatomic, assign) LBAudioStreamerState state;

@property (nonatomic, assign) BOOL localMusic;
@property (nonatomic, assign) BOOL useAudioStream;

/**控制变量*/
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL pauseRequired;
@property (nonatomic, assign) BOOL stopRequired;
@property (nonatomic, assign) BOOL seekRequired;
@property (nonatomic, assign) BOOL pausedByInterrupt;

/**seek控制*/
@property (nonatomic, assign) NSTimeInterval seekTime;
@property (nonatomic, assign) NSTimeInterval timeOffSet;

/**音频资源*/
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) NSURL *audioURL;

@end


@implementation LBAudioPlayer

#pragma mark -
#pragma mark Accessor
-(float)volume{
    return self.audioOutputQueue.volume;
}

- (void)setVolume:(float)volume {
    self.audioOutputQueue.volume = volume;
}

- (NSTimeInterval)duration{
    return self.localMusic ? self.audioFile.duration : self.audioFileStream.duration;
}

- (NSTimeInterval)currentTime{
    if (self.seekRequired) {
        return self.seekTime;
    }
    return self.timeOffSet + self.audioOutputQueue.playedTime;
}

#pragma mark -
#pragma mark  LifeCycle

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cleanUp];
}

- (instancetype)initWithURL:(NSURL *)aUrl
             audioCachePath:(NSString *)cachePath{
    self = [self init];
    if (self) {
        NSAssert(aUrl, @"URL 不能为空");
        self.filePath = cachePath ? cachePath : [NSString papaAudioCachePath:self.audioURL hasType:NO];
        self.audioURL = aUrl;
    }
    return self;
}

- (instancetype)initWithAVURL:(NSURL *)aUrl{
    self = [self init];
    if (self) {
        NSAssert(aUrl, @"URL 不能为空");
        self.audioURL = aUrl;
        self.filePath = [NSString papaAudioCachePath:self.audioURL hasType:YES];
        self.localMusic = YES;
    }
    return self;
}

- (instancetype)initWithFilePath:(NSString *)filePath{
    self = [self init];
    if (self) {
        NSAssert(filePath, @"filePath 不能为空");
        self.useAudioStream = YES;
        self.filePath = filePath;
    }
    return self;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.audioBufferPool = [LBAudioBufferPool bufferPool];
        [self updateAudioState:LBAudioStreamerStateIdle];
        self.started = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

#pragma mark -
#pragma mark Public Methods

- (void)play{
    [[LBAudioSession shareInstance] setActive:YES error:nil];
    
    if (([self isIdle] || [self isStoped]) && !self.started) {
        [self mutexInit];
        self.started = YES;
        [[LBAudioSession shareInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        self.playThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadPlayMain) object:nil];
        [self.playThread start];
        
    } else if(([self isPaused] && !self.pauseRequired) || self.pausedByInterrupt){
        self.pausedByInterrupt = NO;
        [self resume];
    }
}

- (void)paused{
    if ([self isPlaying] || [self isWaitting]) {
        self.pauseRequired = YES;
    }
}

- (void)stop{
    self.stopRequired = YES;
    [self mutexSignal];
}

- (void)seekToTime:(NSTimeInterval)seekTime{
    self.seekRequired = YES;
    self.seekTime = seekTime;
}

#pragma mark -
#pragma mark Private Methods

- (BOOL)isIdle{
    if (self.state == LBAudioStreamerStateIdle) {
        return YES;
    }
    return NO;
}

- (BOOL)isWaitting{
    if (self.state == LBAudioStreamerStateWaitting) {
        return YES;
    }
    return NO;
}

- (BOOL)isPlaying{
    if (self.state == LBAudioStreamerStatePlay || self.state == LBAudioStreamerStateFlushing) {
        return YES;
    }
    return NO;
}

- (BOOL)isPaused{
    if (self.state == LBAudioStreamerStatePause) {
        return YES;
    }
    return NO;
}

- (BOOL)isStoped{
    if (self.state == LBAudioStreamerStateStop) {
        return YES;
    }
    return NO;
}

/** 更新当前播放状态 */
- (void)updateAudioState:(LBAudioStreamerState)state{
    if (state == LBAudioStreamerStateError) {
        NSLog(@"LBAudioStreamerStateError*********");
    }
    if (self.state == state) {
        return;
    }
    self.state = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AudioPlayerStateChangeNotification object:@(state)];
    });
}

- (void)resume{
    [self.audioOutputQueue start];
    [self mutexSignal];
}

/** 是否停止播放 */
- (BOOL)shouldStopped{
    if (self.state == LBAudioStreamerStateStop ||
        self.state == LBAudioStreamerStateError) {
        return YES;
    }
    return NO;
}

- (void)createAudioFileWithError:(NSError **)error{
    __weak LBAudioPlayer *weakSelf = self;
    if (!self.audioFile) {
        if (self.audioURL) {
            self.audioFile = [[LBAudioFile alloc] initWithAsset:self.audioURL cachePath:self.filePath error:error];
        } else {
            self.audioFile = [[LBAudioFile alloc] initWithFilePath:self.filePath fileType:[self hintForFileExtension:self.filePath.pathExtension] error:error];
        }
        if (error) {
            self.audioFile = nil;
        } else {
            self.audioFile.audioFileParsedBlock =  ^(LBAudioFile *audioFile, NSArray *audioDataArray){
                [weakSelf.audioBufferPool enqueueFromDataArray:audioDataArray];
            };
        }
    }
}

- (void)createAudioStreamWithError:(NSError **)error{
    error = nil;
    __weak LBAudioPlayer *weakSelf = self;
    if (!self.audioFileStream) {
        self.audioFileStream = [[LBAudioFileStream alloc] initWithFileType:kAudioFileMP3Type error:error];
        if (self.useAudioStream) {
            self.streamCache = [[LBAudioStreamCache alloc] initWithFilePath:self.filePath];
            self.audioFileStream.fileSize = self.streamCache.contentLength;
        } else {
            self.streamCache = [[LBAudioStreamCache alloc] initWithURL:self.audioURL cachePath:self.filePath];
        }
        if (error) {
            self.audioFileStream = nil;
            self.streamCache = nil;
        } else {
            self.audioFileStream.audioFileParsedBlock =  ^(LBAudioFileStream *audioFileStream, NSArray *audioDataArray){
                [weakSelf.audioBufferPool enqueueFromDataArray:audioDataArray];
            };
        }
    }
}

/** 线程主函数入口 */
- (void)threadPlayMain{
    @autoreleasepool {
        NSError *error = nil;
        //等待数据
        [self updateAudioState:LBAudioStreamerStateWaitting];
        
        //播放控制
        BOOL isEOF = NO;
        
        while (![self shouldStopped] && self.started) {
            @autoreleasepool {
                /*如果AudioFileStream已经readyToProducePackets 或者 缓存池中的数据小于最大缓存数据，则读取原始数据并且解析组装*/
                if ( self.audioBufferPool.bufferPoolSize <= kAQdefaultBufferSize && !isEOF) {
                    if (self.localMusic) {
                        
                        [self createAudioFileWithError:&error];
                        if (error) {
                            [self updateAudioState:LBAudioStreamerStateError];
                            break;
                        }
                        [self.audioFile parseData:&isEOF error:&error];
                        
                    } else {
                        [self createAudioStreamWithError:&error];
                        if (error) {
                            [self updateAudioState:LBAudioStreamerStateError];
                            break;
                        }
                        NSData *data = [self.streamCache readDataOfLength:kAQdefaultBufferSize isEOF:&isEOF error:&error];
                        if (self.audioFileStream.fileSize == 0) {
                            self.audioFileStream.fileSize = self.streamCache.contentLength;
                        }
                        [self.audioFileStream parseData:data error:&error];
                        
                        if (error && self.useAudioStream) {
                            error = nil;
                            self.localMusic = YES;
                            continue;
                        }
                    }
                    
                    if (error) {
                        [self updateAudioState:LBAudioStreamerStateError];
                        break;
                    }
                }
                
                //可以播放操作了
                if (self.localMusic || self.audioFileStream.readyToProducePackets) {
                    
                    //创建音频播放队列
                    if (![self creatAudioQueue]) {
                        [self updateAudioState:LBAudioStreamerStateError];
                        break;
                    }
                    
                    if (self.seekRequired) {
                        self.seekRequired = NO;
                        [self updateAudioState:LBAudioStreamerStateWaitting];
                        self.timeOffSet = self.seekTime - self.audioOutputQueue.playedTime;
                        [self.audioBufferPool clean];
                        if (self.localMusic) {
                            [self.audioFile seekToTime:self.seekTime];
                        } else {
                           SInt64 offset = [self.audioFileStream seekToTime:&_seekTime];
                            [self.streamCache seekToFileOffset:offset];
                        }
                        self.seekRequired = NO;
                        [self.audioOutputQueue reset];
                    }
                    
                    //暂停
                    if (self.pauseRequired) {
                        [self.audioOutputQueue pause];
                        self.pauseRequired = NO;
                        [self updateAudioState:LBAudioStreamerStatePause];
                        
                        [self mutexWait];
                    }
                    
                    //停止
                    if (self.stopRequired) {
                        [self.audioOutputQueue stop:YES];
                        self.stopRequired = NO;
                        self.started = NO;
                        [self updateAudioState:LBAudioStreamerStateStop];
                        break;
                    }
                    
                    //播放
                    if ([self.audioBufferPool bufferPoolSize] > kAQdefaultBufferSize || isEOF) {
                        UInt32 packetCount = 0;
                        AudioStreamPacketDescription *desces = NULL;
                        NSData *data = [self.audioBufferPool dequeueDataWithSize:kAQdefaultBufferSize
                                                                     packetCount:&packetCount
                                                                    descriptions:&desces];
                        if (packetCount != 0){
                            BOOL succeed = [self.audioOutputQueue playWithParsedData:data
                                                                         packetCount:packetCount
                                                                  packetDescriptions:desces
                                                                               isEOF:isEOF];
                            free(desces);
                            if (!succeed) {
                                [self updateAudioState:LBAudioStreamerStateError];
                                break;
                            }
                            
                            if ([self.audioBufferPool isEmpty] && isEOF){
                                [self.audioOutputQueue stop:NO];
                                [self updateAudioState:LBAudioStreamerStateFlushing];
                                break;
                            }
                        } else if (isEOF){
                        } else {
                            [self updateAudioState:LBAudioStreamerStateError];
                            break;
                        }
                    }
                }
            }
        }
        
        while (self.audioOutputQueue.isRunning && self.state == LBAudioStreamerStateFlushing) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }

        //重置
        [self cleanUp];
    }
}

- (void)cleanUp{
    //清空缓存池
    [self.audioBufferPool clean];
    
    //关闭文件
    [self.audioFile close];
    self.audioFile = nil;
    [self.audioFileStream close];
    self.audioFileStream = nil;
    self.streamCache = nil;
    
    //关闭播放器
    [self.audioOutputQueue stop:YES];
    
    //销毁锁
    [self mutexDestory];
    
    //重置所有控制变量
    [self updateAudioState:LBAudioStreamerStateStop];
    self.seekTime = 0;
    self.timeOffSet = 0;
    self.started = NO;
    self.stopRequired = NO;
    self.pauseRequired = NO;
    self.seekRequired = NO;
}


/** 创建音频播放队列 */
- (BOOL)creatAudioQueue{
    if (self.audioOutputQueue) {
        return YES;
    }
    
    AudioStreamBasicDescription format = self.localMusic ? self.audioFile.format : self.audioFileStream.format;
    NSData *magicCookie = self.localMusic ? [self.audioFile fetchMagicCookie] : [self.audioFileStream fetchMagicCookie];
    self.audioOutputQueue = [[LBAudioOutputQueue alloc] initWithFormat:format
                                                            bufferSize:kAQdefaultBufferSize
                                                          macgicCookie:magicCookie];
    if (!self.audioOutputQueue.isAvailable) {
        self.audioOutputQueue = nil;
        return NO;
    }
    __weak LBAudioPlayer *weakSelf = self;
    self.audioOutputQueue.audioQueueBlock = ^(BOOL waitting){
        if (waitting) {
            [weakSelf updateAudioState:LBAudioStreamerStateWaitting];
        } else {
            [weakSelf updateAudioState:LBAudioStreamerStatePlay];
        }
    };
    return YES;
}

- (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension{
    AudioFileTypeID fileTypeHint = 0;
    if ([fileExtension isEqual:@"mp3"]){
        fileTypeHint = kAudioFileMP3Type;
    } else if ([fileExtension isEqual:@"wav"]){
        fileTypeHint = kAudioFileWAVEType;
    } else if ([fileExtension isEqual:@"aifc"]){
        fileTypeHint = kAudioFileAIFCType;
    } else if ([fileExtension isEqual:@"aiff"]){
        fileTypeHint = kAudioFileAIFFType;
    } else if ([fileExtension isEqual:@"m4a"]){
        fileTypeHint = kAudioFileM4AType;
    } else if ([fileExtension isEqual:@"mp4"]) {
        fileTypeHint = kAudioFileMPEG4Type;
    } else if ([fileExtension isEqual:@"caf"]){
        fileTypeHint = kAudioFileCAFType;
    } else if ([fileExtension isEqual:@"aac"]){
        fileTypeHint = kAudioFileAAC_ADTSType;
    }
    return fileTypeHint;
}

#pragma mark -
#pragma mark   Notification

- (void)audioSessionInterruptionNotification:(NSNotification *)notification{
    UInt32 interruptionState = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntValue];
    if (interruptionState == kAudioSessionBeginInterruption){
        if ([self isPlaying]) {
            self.pausedByInterrupt = YES;
            [self.audioOutputQueue pause];
            [self updateAudioState:LBAudioStreamerStatePause];
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioPlayerBeginInterruption:)]) {
                [self.delegate audioPlayerBeginInterruption:self];
            }
        }
    } else if (interruptionState == kAudioSessionEndInterruption){
        if (self.pausedByInterrupt) {
            [self play];
            if (self.delegate && [self.delegate respondsToSelector:@selector(audioPlayerEndInterruption:)]) {
                [self.delegate audioPlayerEndInterruption:self];
            }
        }
    }
}

//ios监听输出设备变化
- (void)audioSessionRouteChangeNotification:(NSNotification *)notification{
    
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

@end