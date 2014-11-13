//
//  LBAudioFile.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/5.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioFile.h"
#import <pthread.h>
#import <AVFoundation/AVFoundation.h>
#import "LBParsedAudioData.h"
#import "LBAudioDefine.h"

static const UInt32 packetPerRead = 3;

@interface LBAudioFile (){
    pthread_mutex_t mutex;
    pthread_cond_t cond;
}

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) AudioFileTypeID fileType;
@property (nonatomic, strong) NSFileHandle       *fileHandle;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, assign) AudioFileID        audioFileID;

@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval packetDuration;
@property (nonatomic, assign) UInt32 maxPacketSize;
@property (nonatomic, assign) UInt32 bitRate;
@property (nonatomic, assign) SInt64 dataOffset;
@property (nonatomic, assign) UInt64 audioDataByteCount;
@property (nonatomic, assign) SInt64 packetOffset;

@property (nonatomic, assign) AudioStreamBasicDescription format;

@end


#pragma mark -
#pragma mark    static callbacks

/**
 @param      inPosition		An offset into the data from which to read.
 @param      requestCount	The number of bytes to read.
 @param      buffer			The buffer in which to put the data read.
 @param      actualCount	The callback should set this to the number of bytes successfully read.
 */
static OSStatus audioFileReadProc(void *inClientData,
                                  SInt64 inPosition,
                                  UInt32 requestCount,
                                  void *buffer,
                                  UInt32 *actualCount){
    LBAudioFile *audioFile = (__bridge LBAudioFile *)inClientData;
    
    if ((inPosition + requestCount) > audioFile.fileSize){
        *actualCount = inPosition > audioFile.fileSize ? 0 : (UInt32)(audioFile.fileSize - inPosition);
    } else {
        *actualCount = requestCount;
    }
    
    if (*actualCount > 0){
        [audioFile.fileHandle seekToFileOffset:inPosition];
        NSData *data = [audioFile.fileHandle readDataOfLength:*actualCount];
        memcpy(buffer, [data bytes], [data length]);
    }
    return noErr;
}

static SInt64 audioFileGetSizeProc(void *inClientData){
    LBAudioFile *audioFile = (__bridge LBAudioFile *)inClientData;
    return audioFile.fileSize;
}

@implementation LBAudioFile

#pragma mark -
#pragma mark  Life Cycle

- (void)dealloc{
    [self.fileHandle closeFile];
    [self closeAudioFile];
}

- (instancetype)initWithFilePath:(NSString *)filePath
                        fileType:(AudioFileTypeID)fileType
                           error:(NSError **)error{
    self = [super init];
    if (self) {
        self.filePath = filePath;
        self.fileType = fileType;
        [self initSettings];
    }
    return self;
}

- (instancetype)initWithAsset:(NSURL *)iPodUrl
                    cachePath:(NSString *)cachePath
                        error:(NSError **)error{
    self = [super init];
    if (self) {
        self.url = iPodUrl;
        if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:nil]) {
            self.filePath = cachePath;
            self.fileType = kAudioFileCAFType;
            [self initSettings];
        } else {
            [self exportiPodMusicWithURL:iPodUrl cachePath:cachePath error:error];
        }
    }
    return self;
}

- (void)exportiPodMusicWithURL:(NSURL *)url cachePath:(NSString *)cachePath error:(NSError **)error{
    __weak LBAudioFile *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        AVAssetExportSession *assetExportSession = [AVAssetExportSession exportSessionWithAsset:asset
                                                                                     presetName:AVAssetExportPresetPassthrough];
        [assetExportSession setOutputFileType:AVFileTypeCoreAudioFormat];
        [assetExportSession setOutputURL:[NSURL fileURLWithPath:cachePath]];
        [assetExportSession exportAsynchronouslyWithCompletionHandler:^{
            switch (assetExportSession.status) {
                case AVAssetExportSessionStatusCompleted: {
                    weakSelf.fileType = kAudioFileCAFType;
                    weakSelf.filePath = cachePath;
                    [weakSelf initSettings];
                    [weakSelf mutexSignal];
                    [weakSelf mutexDestory];
                    LBLog(@"导出成功");
                }
                    break;
                default:{
                    LBLog(@"导出失败:%@",assetExportSession.error);
                    *error = [NSError errorWithDomain:@"导出失败" code:100 userInfo:nil];
                    [weakSelf mutexSignal];
                    [weakSelf mutexDestory];
                }
                    break;
            }
        }];

    });
    [self mutexInit];
    [self mutexWait];
}

- (void)initSettings{
    self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
    self.fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil] fileSize];
    if (self.fileSize > 0 && self.fileHandle) {
        if ([self openAudioFileWithFileTypeHint:self.fileType]) {
            [self fetchFormatInfo];
        }
    } else {
        [self.fileHandle closeFile];
    }
}

#pragma mark -
#pragma mark  Pubish Methods

- (void)parseData:(BOOL *)isEof error:(NSError **)error{
    error = nil;
    
    UInt32 ioNumPackets = packetPerRead;
    UInt32 ioNumBytes = ioNumPackets * self.maxPacketSize;
    void * outBuffer = (void *)malloc(ioNumBytes);
    
    UInt32 descSize = sizeof(AudioStreamPacketDescription) * ioNumPackets;
    AudioStreamPacketDescription * outPacketDescriptions = (AudioStreamPacketDescription *)malloc(descSize);
    
    OSStatus status = AudioFileReadPacketData(_audioFileID,
                                              false,
                                              &ioNumBytes,
                                              outPacketDescriptions,
                                              self.packetOffset,
                                              &ioNumPackets,
                                              outBuffer);
    if (status != noErr){
        LBLog(@"%@",OSStatusCode(status));
        if (status == kAudioFileEndOfFileError) {
            *isEof = YES;
        } else {
            *error = [NSError errorWithDomain:@"AudioFileReadPacketData Error" code:100 userInfo:nil];
        }
    }
    
    if (ioNumBytes == 0){
        *isEof = YES;
    }
    
    if (ioNumPackets > 0){
        self.packetOffset += ioNumPackets;
        NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < ioNumPackets; ++i){
            @autoreleasepool {
                AudioStreamPacketDescription packetDescriptioin = outPacketDescriptions[i];
                LBParsedAudioData *parsedData = [LBParsedAudioData parsedAudioDataWithBytes:outBuffer + packetDescriptioin.mStartOffset
                                                                          packetDescription:packetDescriptioin];
                [parsedDataArray addObject:parsedData];
            }
        }
        if (self.audioFileParsedBlock) {
            self.audioFileParsedBlock(self,parsedDataArray);
        }
    }
    free(outBuffer);
    free(outPacketDescriptions);
}

- (NSData *)fetchMagicCookie{
    UInt32 cookieSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status != noErr){
        return nil;
    }
    
    void *cookieData = malloc(cookieSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookieData);
    if (status != noErr){
        free(cookieData);
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    return cookie;
}

- (void)seekToTime:(NSTimeInterval)time{
    self.packetOffset = floor(time / self.packetDuration);
}

- (void)close{
    [self closeAudioFile];
}


#pragma mark -
#pragma mark  Private Method

- (BOOL)openAudioFileWithFileTypeHint:(AudioFileTypeID)fileType{
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void *)self,
                                                 audioFileReadProc,
                                                 NULL,
                                                 audioFileGetSizeProc,
                                                 NULL,
                                                 fileType,
                                                 &_audioFileID);
    if (status != noErr){
        self.audioFileID = NULL;
        LBLog(@"AudioFileOpenWithCallbacks失败:%@",OSStatusCode(status));
        return NO;
    }
    return YES;
}

- (void)calculatepPacketDuration{
    if (self.format.mSampleRate > 0){
        self.packetDuration = self.format.mFramesPerPacket / self.format.mSampleRate;
    }
}

- (void)calculateDuration{
    if (self.fileSize > 0 && self.bitRate > 0){
        self.duration = ((self.fileSize - self.dataOffset) * 8) / self.bitRate;
    }
}

- (void)fetchFormatInfo{
    UInt32 formatListSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr){
        BOOL found = NO;
        
        AudioFormatListItem *formatList = malloc(formatListSize);
        OSStatus status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, formatList);
        if (status == noErr){
            UInt32 supportedFormatsSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
            if (status != noErr){
                free(formatList);
                LBLog(@"AudioFormatGetPropertyInfo 失败:%@",OSStatusCode(status));
                [self closeAudioFile];
                return;
            }
            
            UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
            OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
            if (status != noErr){
                free(formatList);
                free(supportedFormats);
                LBLog(@"AudioFormatGetProperty 失败:%@",OSStatusCode(status));
                [self closeAudioFile];
                return;
            }
            
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem)){
                AudioStreamBasicDescription format = formatList[i].mASBD;
                for (UInt32 j = 0; j < supportedFormatCount; ++j){
                    if (format.mFormatID == supportedFormats[j]){
                        _format = format;
                        found = YES;
                        break;
                    }
                }
            }
            free(supportedFormats);
        }
        free(formatList);
        
        if (!found){
            LBLog(@"获取 format 失败");
            [self closeAudioFile];
            return;
        } else {
            [self calculatepPacketDuration];
        }
    }
    
    UInt32 bitRate;
    UInt32 size = sizeof(bitRate);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyBitRate, &size, &bitRate);
    if (status != noErr){
        LBLog(@"比特率 失败");
        [self closeAudioFile];
        return;
    }
    self.bitRate = bitRate;
    
    SInt64 dataOffset;
    size = sizeof(dataOffset);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataOffset, &size, &dataOffset);
    if (status != noErr){
        LBLog(@"偏移 失败");
        [self closeAudioFile];
        return;
    }
    self.dataOffset = dataOffset;
    self.audioDataByteCount = self.fileSize - self.dataOffset;
    
    NSTimeInterval duration;
    size = sizeof(duration);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyEstimatedDuration, &size, &duration);
    if (status != noErr){
        [self calculateDuration];
    } else {
        self.duration = duration;
    }
    
    UInt32 maxPacketSize;
    size = sizeof(maxPacketSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
    if (status != noErr || maxPacketSize == 0){
        status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &maxPacketSize);
        if (status != noErr){
            LBLog(@"包的最大值 失败");
            [self closeAudioFile];
            return;
        }
    }
    self.maxPacketSize = maxPacketSize;
    
}

- (void)closeAudioFile{
    if (self.audioFileID){
        AudioFileClose(self.audioFileID);
        self.audioFileID = NULL;
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


@end
