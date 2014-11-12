//
//  LBAudioFileStream.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioFileStream.h"
#import "LBParsedAudioData.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 50

@interface LBAudioFileStream (){

    AudioFileStreamID _audioFileStreamID;
    
}

@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) UInt32 bitRate;
@property (nonatomic, assign) SInt64 dataOffset;
@property (nonatomic, assign) UInt64 audioDataByteCount;
@property (nonatomic, assign) UInt64 audioDataPacketCount;

@property (nonatomic, assign) BOOL discontinuous;
@property (nonatomic, assign) BOOL readyToProducePackets;

@property (nonatomic, assign) AudioStreamBasicDescription format;
@property (nonatomic, assign) UInt64 processedPacketsCount;
@property (nonatomic, assign) SInt64 processedPacketsSizeTotal;
@property (nonatomic, assign) NSTimeInterval packetDuration;

- (void)handlePropertyListenerProForFileStream:(AudioFileStreamID)inAudioFileStream
                                    propertyID:(AudioFileStreamPropertyID)inPropertyID
                                       ioFlags:(UInt32 *)ioFlags;

- (void)handlePacketsPro:(const void *)inInputData
             numberBytes:(UInt32)inNumberBytes
           numberPackets:(UInt32)inNumberPackets
      packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
@end

#pragma mark -
#pragma mark    static callbacks

/*歌曲信息解析的回调，每解析出一个歌曲信息都会进行一次回调*/
void audioFileStream_PropertyListenerProc(void *						inClientData,
                                          AudioFileStreamID			inAudioFileStream,
                                          AudioFileStreamPropertyID	inPropertyID,
                                          UInt32 *					ioFlags){
    LBAudioFileStream *audioStream = (__bridge LBAudioFileStream *)inClientData;
    [audioStream handlePropertyListenerProForFileStream:inAudioFileStream
                                               propertyID:inPropertyID
                                                  ioFlags:ioFlags];
}

/*找到音频数据的时候会回调，每解析出一部分帧就会进行一次回调*/
void audioFileStream_PacketsProc(void *							inClientData,
                                 UInt32							inNumberBytes,
                                 UInt32							inNumberPackets,
                                 const void *					inInputData,
                                 AudioStreamPacketDescription	*inPacketDescriptions){
    LBAudioFileStream *audioStream = (__bridge LBAudioFileStream *)inClientData;
    [audioStream handlePacketsPro:inInputData
                        numberBytes:inNumberBytes
                      numberPackets:inNumberPackets
                 packetDescriptions:inPacketDescriptions];
}


@implementation LBAudioFileStream

#pragma mark -
#pragma mark Accessor

- (void)dealloc{
    [self closeAudioFileStream];
}

- (instancetype)initWithFileType:(AudioFileTypeID)fileType
                           error:(NSError **)error{
    self = [super init];
    if (self) {
        [self openAudioFileStreamWithFileTypeHint:fileType
                                            error:error];
    }
    return self;
}

#pragma mark -
#pragma mark   Public Mehtods

/*音频文件数据解析*/
- (BOOL)parseData:(NSData *)data error:(NSError **)error{
    if (self.readyToProducePackets && self.packetDuration == 0){
        return NO;
    }
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID,
                                                (UInt32)[data length],
                                                [data bytes],
                                                self.discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0);
    
    if (status != noErr) {
        NSLog(@"AudioFileStreamParseBytes 失败");
        return NO;
    }
    return YES;
}

- (NSData *)fetchMagicCookie{
    UInt32 cookieSize;
	Boolean writable;
	OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID,
                                                     kAudioFileStreamProperty_MagicCookieData,
                                                     &cookieSize,
                                                     &writable);
	if (status != noErr){
		return nil;
	}
    
	// get the cookie data
	void* cookieData = calloc(1, cookieSize);
	status = AudioFileStreamGetProperty(_audioFileStreamID,
                                        kAudioFileStreamProperty_MagicCookieData,
                                        &cookieSize,
                                        cookieData);
	if (status != noErr){
        free(cookieData);
		return nil;
	}
    
    NSData *cookie = [NSData dataWithBytes:cookieData
                                    length:cookieSize];
    free(cookieData);
    
    return cookie;
}


- (SInt64)seekToTime:(NSTimeInterval *)time{
    self.discontinuous = YES;
    SInt64 seekByteOffset = self.dataOffset + (*time / self.duration) * self.audioDataByteCount;
    SInt64 seekToPacket = floor(*time / self.packetDuration);
    SInt64 outDataByteOffset;
    UInt32 ioFlags = 0;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID,
                                          seekToPacket,
                                          &outDataByteOffset,
                                          &ioFlags);
    
    if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)){
        *time -= ((seekByteOffset - self.dataOffset) - outDataByteOffset) * 8.0 / self.bitRate;
        seekByteOffset = outDataByteOffset + self.dataOffset;
    }
    return seekByteOffset;
}


- (void)close{
    [self closeAudioFileStream];
    self.dataOffset = 0;
}

#pragma mark -
#pragma mark    open && close fileStream

/* 开启AudioFileStream */
- (BOOL)openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint
                                      error:(NSError **)error{
    OSStatus status = AudioFileStreamOpen((__bridge void *)self,
                                          audioFileStream_PropertyListenerProc,
                                          audioFileStream_PacketsProc,
                                          fileTypeHint,
                                          &_audioFileStreamID);
    
    if (status != noErr){
        _audioFileStreamID = NULL;
        return NO;
    }
    return status == noErr;
}

/* 关闭AudioFileStream */
- (void)closeAudioFileStream{
    if (_audioFileStreamID != NULL){
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}

#pragma mark -
#pragma mark   calculate(estimate) Method

/*
 
 采样位数 即采样值或取样值 是记录每次采样值数值大小的位数
 
 采样频率 是指单位时间内的采样次数  一般共分为22.05KHz、44.1KHz、48KHz三个等级
 
 声道数   是指处理的声音是单声道还是立体声 其中，单声道的声道数为1，立体声的声道数为2。
 
 数据量=（采样频率×采样位数×声道数×时间)/8 = 时间×比特率/8
 
*/

- (void)calculatepPacketDuration{
    if (self.format.mSampleRate > 0){
        self.packetDuration = self.format.mFramesPerPacket / self.format.mSampleRate;
    }
}

- (void)calculateBitRate{
    if (self.packetDuration && self.processedPacketsCount > BitRateEstimationMinPackets && self.processedPacketsCount <= BitRateEstimationMaxPackets && !self.bitRate){
        double averagePacketByteSize = self.processedPacketsSizeTotal / self.processedPacketsCount;
        self.bitRate = 8.0 * averagePacketByteSize / self.packetDuration;
    }
}

- (void)calculateDuration{
    if (self.audioDataByteCount > 0 && self.bitRate > 0){
        self.duration = ceilf(((self.audioDataByteCount - self.dataOffset) * 8) / (float)self.bitRate);
    }
}

#pragma mark -
#pragma mark   fileStream Callback Function Implementations

- (void)handlePropertyListenerProForFileStream:(AudioFileStreamID)inAudioFileStream
                                    propertyID:(AudioFileStreamPropertyID)inPropertyID
                                       ioFlags:(UInt32 *)ioFlags{
    NSLog(@"Property is %c%c%c%c",
            ((char *)&inPropertyID)[3],
            ((char *)&inPropertyID)[2],
            ((char *)&inPropertyID)[1],
            ((char *)&inPropertyID)[0]);
   
    if (inPropertyID == kAudioFileStreamProperty_BitRate) {
        //音频数据的码率,为了计算音频的总时长Duration
        UInt32 bitRate;
        UInt32 bitRateSize = sizeof(bitRate);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                                       kAudioFileStreamProperty_BitRate,
                                                       &bitRateSize,
                                                       &bitRate);
        if (osStatus != noErr){
            return;
        }
        
        if (bitRate > 1000) {
            self.bitRate = bitRate;
        } else {
            self.bitRate = bitRate * 1000;
        }
    } else if (inPropertyID == kAudioFileStreamProperty_AudioDataByteCount){
        //音频文件中音频数据的总量。一是用来计算音频的总时长，二是可以在seek时用来计算时间对应的字节offset
        UInt64 audioDataByteCount;
        UInt32 byteCountSize = sizeof(audioDataByteCount);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                              kAudioFileStreamProperty_AudioDataByteCount,
                                              &byteCountSize,
                                              &audioDataByteCount);
        if (osStatus != noErr){
            return;
        }
        self.audioDataByteCount = audioDataByteCount;
        
    } else if (inPropertyID == kAudioFileStreamProperty_AudioDataPacketCount){
        //音频文件中数据包的总数
        UInt64 audioDataPacketCount;
        UInt32 byteCountSize = sizeof(audioDataPacketCount);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                                      kAudioFileStreamProperty_AudioDataPacketCount,
                                                      &byteCountSize,
                                                      &audioDataPacketCount);
        if (osStatus != noErr){
            return;
        }
        self.audioDataPacketCount = audioDataPacketCount;
    } else if (inPropertyID == kAudioFileStreamProperty_FileFormat){
        //音频文件的格式
        UInt32 fileFormat;
        UInt32 fileFormatSize= sizeof(fileFormat);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                              kAudioFileStreamProperty_FileFormat,
                                              &fileFormatSize,
                                              &fileFormat);
        if (osStatus != noErr){
            return;
        }
        NSString *fileFormatString = [NSString stringWithFormat:@"%c%c%c%c",((char *)&fileFormat)[3],
                                ((char *)&fileFormat)[2],
                                ((char *)&fileFormat)[1],
                                ((char *)&fileFormat)[0]];
        NSLog(@"fileFormat: %@", fileFormatString);
        
    } else if (inPropertyID == kAudioFileStreamProperty_DataFormat){
        //音频文件结构信息，是一个AudioStreamBasicDescription的结构
        UInt32 formatSize = sizeof(_format);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                              kAudioFileStreamProperty_DataFormat,
                                              &formatSize,
                                              &_format);
        if (osStatus != noErr){
            return;
        }
        [self calculatepPacketDuration];
        
    } else if (inPropertyID == kAudioFileStreamProperty_DataOffset){ //SInt64 相对音频数据开始的偏移量seekoffset
        SInt64 dataOffset;
        UInt32 offsetSize = sizeof(dataOffset);
        OSStatus osStatus = AudioFileStreamGetProperty(inAudioFileStream,
                                              kAudioFileStreamProperty_DataOffset,
                                              &offsetSize,
                                              &dataOffset);
        if (osStatus != noErr){
            return;
        }
        self.dataOffset = dataOffset;
        self.audioDataByteCount = self.fileSize - self.dataOffset;
    } else if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets){
        //不必获取对应的值，一旦回调中这个PropertyID出现就代表解析完成，接下来可以对音频数据进行帧分离了
        self.discontinuous = YES;
        self.readyToProducePackets = YES;
    } else if (inPropertyID == kAudioFileStreamProperty_FormatList){
        //类似kAudioFileStreamProperty_DataFormat，区别在于获取到是一个AudioStreamBasicDescription的数组，这个参数是用来支持AAC SBR这样的包含多个文件类型的银屏格式
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID,
                                                         kAudioFileStreamProperty_FormatList,
                                                         &formatListSize,
                                                         &outWriteable);
        if (status == noErr){
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID,
                                                         kAudioFileStreamProperty_FormatList,
                                                         &formatListSize,
                                                         formatList);
            if (status == noErr){
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs,
                                                    0,
                                                    NULL,
                                                    &supportedFormatsSize);
                if (status != noErr){
                    free(formatList);
                    return;
                }
                
                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs,
                                                0,
                                                NULL,
                                                &supportedFormatCount,
                                                supportedFormats);
                if (status != noErr){
                    free(formatList);
                    free(supportedFormats);
                    return;
                }
                
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem)){
                    AudioStreamBasicDescription format = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; ++j){
                        if (format.mFormatID == supportedFormats[j]){
                            _format = format;
                            [self calculatepPacketDuration];
                            break;
                        }
                    }
                }
                free(supportedFormats);
            }
            free(formatList);
        }
    }
}

/*
 inInputData ---The audio data
 inNumberBytes --- The number of bytes of data in the inInputData buffer.
 inNumberPackets --- The number of packets of audio data in the inInputData buffer.
 nPacketDescriptions --- An array of audio file stream packet description structures describing the data
 
 struct  AudioStreamPacketDescription
 {
 SInt64  mStartOffset;
 UInt32  mVariableFramesInPacket;//实际的数据帧只有VBR的数据才能用到像MP3这样的压缩数据一个帧里会有好几个数据帧）
 UInt32  mDataByteSize;
 };
 */

- (void)handlePacketsPro:(const void *)inInputData
             numberBytes:(UInt32)inNumberBytes
           numberPackets:(UInt32)inNumberPackets
      packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions{
    
    if (self.discontinuous) {
        self.discontinuous = NO;
    }
    
    if (inNumberBytes == 0 || inNumberPackets == 0) {
        return;
    }
    
    BOOL deletePackDesc = NO;
    //如果inPacketDescriptions不存在，就按照CBR处理，平均每一帧的数据后 生成packetDescriptioins
    if (inPacketDescriptions == NULL){
        deletePackDesc = YES;
        AudioStreamPacketDescription *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);
        
        UInt32 packetSize = inNumberBytes / inNumberPackets;

        for (int i = 0; i < inNumberPackets; i++){
            @autoreleasepool {
                UInt32 packetOffset = packetSize * i;
                descriptions[i].mStartOffset = packetOffset;
                descriptions[i].mVariableFramesInPacket = 0;
                if (i == inNumberPackets - 1){
                    descriptions[i].mDataByteSize = inNumberBytes - packetOffset;
                } else {
                    descriptions[i].mDataByteSize = packetSize;
                }
            }
        }
        inPacketDescriptions = descriptions;
    }
    
    NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < inNumberPackets; ++i){
        @autoreleasepool {
            SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
            LBParsedAudioData *parsedData = [LBParsedAudioData parsedAudioDataWithBytes:inInputData + packetOffset
                                                                      packetDescription:inPacketDescriptions[i]];
            [parsedDataArray addObject:parsedData];
            
            //计算平均比特率
            if (self.processedPacketsCount < BitRateEstimationMaxPackets){
                self.processedPacketsSizeTotal += parsedData.packetDescription.mDataByteSize;
                self.processedPacketsCount += 1;
               [self calculateBitRate];
               [self calculateDuration];
            }
        }
    }
    
    if (deletePackDesc){
        free(inPacketDescriptions);
    }
    
    if (self.audioFileParsedBlock) {
        self.audioFileParsedBlock(self,parsedDataArray);
    }
}

@end
