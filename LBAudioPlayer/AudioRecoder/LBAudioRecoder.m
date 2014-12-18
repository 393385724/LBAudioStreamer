//
//  LBAudioRecoder.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/** 
录音支持的格式 10秒录音大小kb/10s
 kAudioFormatMPEG4AAC : 164,
 kAudioFormatAppleLossless : 430,
 kAudioFormatAppleIMA4 : 475,
 kAudioFormatULaw : 889,
 kAudioFormatALaw : 889,
 */

#import "LBAudioRecoder.h"
#import "LBAudioInputQueue.h"
#import "LBRecoderFile.h"
#import "LBAudioSession.h"
#import "LBAudioDefine.h"

@interface LBAudioRecoder ()<LBAudioInputQueueDelegate>{
    AudioStreamBasicDescription recoderFormat;
}

@property (nonatomic, strong) LBAudioInputQueue   *audioInputQueue;
@property (nonatomic, strong) LBRecoderFile       *recoderFile;
@property (nonatomic, strong) NSDictionary        *settings;

@property (nonatomic, copy) NSString *recoderFilePath;

@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) SInt64	  recordPacket; // current packet number in record file
@property (nonatomic, assign) SInt64	  recordMaxPacket;

@property (nonatomic, assign) BOOL pauseRequired;

@end

@implementation LBAudioRecoder

#pragma mark -
#pragma mark  Accessor

- (NSString *)path{
    return self.recoderFilePath;
}

-(NSTimeInterval)currentTime{
    if (self.audioInputQueue.isRunning) {
        _currentTime = self.audioInputQueue.recoderTime + self.timeOffset;
    }
    return _currentTime;
}

- (float)level{
    if (self.meteringEnabled) {
        [self.audioInputQueue updateMeters];
        float volume = powf(10, [self.audioInputQueue averagePowerForChannel:0] / 2 / 20) * 1.3;
        return volume;
    }else{
        return 0;
    }
}

#pragma mark -
#pragma mark LifecCycle

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFilePath:(NSString *)filePath
                        settings:(NSDictionary *)settings
                           error:(NSError **)outError{
    self = [super init];
    if (self) {
        NSAssert(filePath, @"filePath not be nil");
        self.recoderFilePath = filePath;
        self.meteringEnabled = NO;
        self.settings = settings;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

- (BOOL)prepareToRecord{
    [[LBAudioSession shareInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[LBAudioSession shareInstance] setActive:YES error:nil];
    [self setUpRecoderFormat];
    self.audioInputQueue = [[LBAudioInputQueue alloc] initWithFormat:recoderFormat];
    self.audioInputQueue.delegate = self;
    self.audioInputQueue.meteringEnabled = self.meteringEnabled;
    
    self.recoderFile = [[LBRecoderFile alloc] initWithFilePath:self.recoderFilePath fileType:kAudioFileCAFType format:recoderFormat error:nil];
    [self copyMagicCookieToFile];
    
    return YES;
}

- (BOOL)record{
    if (!self.pauseRequired) {
        BOOL success = [self prepareToRecord];
        if (success) {
            return [self.audioInputQueue start];
        } else {
            return NO;
        }
    } else {
        return [self.audioInputQueue start];
    }
}

- (BOOL)recordForDuration:(NSTimeInterval) duration{
    self.recordMaxPacket = recoderFormat.mSampleRate * duration / recoderFormat.mFramesPerPacket;
    LBLog(@"recordMaxPacket: %lld,duration: %f",self.recordMaxPacket,duration);
    return [self record];
}

- (void)rollback{
    
}

- (void)pause{
    self.pauseRequired = YES;
    [self.audioInputQueue pause];
}

- (void)stop{
    self.timeOffset = self.currentTime;
    [self.audioInputQueue stop];
    [self copyMagicCookieToFile];
}

- (BOOL)deleteRecording{
    [self.audioInputQueue stop];
    BOOL isDirectory;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.recoderFilePath isDirectory:&isDirectory]) {
        if (!isDirectory) {
            [[NSFileManager defaultManager] removeItemAtPath:self.recoderFilePath error:nil];
        }
    }
    return YES;
}

#pragma mark -
#pragma mark private Methods

- (void)copyMagicCookieToFile{
    NSData *magicData;
    UInt32 magicSize;
    BOOL success = [self.audioInputQueue copyEncoderCookie:&magicData size:&magicSize];
    if (success) {
        [self.recoderFile setMagicCookie:magicData magicCookieSize:magicSize];
    }
}

- (void)setUpRecoderFormat {
    memset(&recoderFormat, 0, sizeof(recoderFormat));
    if (self.settings) {
        recoderFormat.mFormatID = [self.settings[AVFormatIDKey] intValue];
        recoderFormat.mSampleRate = [self.settings[AVSampleRateKey] floatValue];
        recoderFormat.mChannelsPerFrame = [self.settings[AVNumberOfChannelsKey] intValue];
    } else {
        recoderFormat.mFormatID = kAudioFormatLinearPCM;
        recoderFormat.mSampleRate = 16000.0;
        recoderFormat.mChannelsPerFrame = 1;
        recoderFormat.mFramesPerPacket = 1;
        recoderFormat.mBitsPerChannel = 16;
        recoderFormat.mBytesPerFrame = (recoderFormat.mBitsPerChannel / 8) * recoderFormat.mChannelsPerFrame;
        recoderFormat.mBytesPerPacket = recoderFormat.mBytesPerFrame * recoderFormat.mFramesPerPacket;
        recoderFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger| kLinearPCMFormatFlagIsPacked;
    }
}


#pragma mark -
#pragma mark LBAudioInputQueueDelegate

- (BOOL)handleBufferFillingCompleteBuffer:(AudioQueueBufferRef)inBuffer
                                startTime:(const AudioTimeStamp *)inStartTime
                 NumberPacketDescriptions:(UInt32)inNumberPacketDescriptions
                              PacketDescs:(const AudioStreamPacketDescription *)inPacketDescs{
   BOOL success = [self.recoderFile writePackets:inNumberPacketDescriptions
                                      bufferData:inBuffer->mAudioData
                                  bufferDataSize:inBuffer->mAudioDataByteSize
                                  startingPacket:self.recordPacket
                                      packetDesc:inPacketDescs];
    if (success) {
        self.recordPacket += inNumberPacketDescriptions;
        return YES;
    } else {
        return NO;
    }
}

#pragma mark -
#pragma mark   Notification

- (void)audioSessionInterruptionNotification:(NSNotification *)notification{
    UInt32 interruptionState = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntValue];
    if (interruptionState == kAudioSessionBeginInterruption){
        if (self.delegate && [self.delegate respondsToSelector:@selector(audioRecoderBeginInterruption:)]) {
            [self.delegate audioRecoderBeginInterruption:self];
        }
    } else if (interruptionState == kAudioSessionEndInterruption){
        if (self.delegate && [self.delegate respondsToSelector:@selector(audioRecoderEndInterruption:)]) {
            [self.delegate audioRecoderEndInterruption:self];
        }
    }
}

//ios监听输出设备变化
- (void)audioSessionRouteChangeNotification:(NSNotification *)notification{
    
}
@end
