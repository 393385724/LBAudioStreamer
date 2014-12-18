//
//  LBMixAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/16.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBMixAudioFilter.h"

@interface LBMixAudioFilter ()

@property (nonatomic, assign) LBAudioSampleType *carrierSamples;  //总的样本数据指针
@property (nonatomic, assign) UInt32 totalSampleCount;     //所有的样本数

@property (nonatomic, assign) UInt32 currentSampleCount;  //当前已经读取的样本数

@end

@implementation LBMixAudioFilter

- (void)dealloc{
    free(_carrierSamples);
}

- (instancetype)initWithFilterPath:(NSString *)filterPath
                     bgMusicVolume:(CGFloat)bgMusicVolume{
    self = [super init];
    if (self) {
        self.bgMusicVolume = bgMusicVolume;
        if (![self getMixFilterInfoWithFilterPath:filterPath]) {
            return nil;
        }
    }
    return self;
}

- (UInt32)doFilter:(LBAudioSampleType *)sourceSamples sampleNumber:(UInt32)sampleNumber{
    LBAudioSampleType *carrierSamples4ThisTime = (LBAudioSampleType *)malloc(sampleNumber * LBAudioSampleTypeSize);
    LBAudioSampleType *current = carrierSamples4ThisTime;
    UInt32 startOfCarrier = self.currentSampleCount % self.totalSampleCount;
    self.currentSampleCount += sampleNumber;
    UInt32 endOfCarrier = self.currentSampleCount % self.totalSampleCount;
    
    if (startOfCarrier > endOfCarrier) {
        memcpy(current, _carrierSamples+startOfCarrier, (self.totalSampleCount-startOfCarrier) * LBAudioSampleTypeSize);
        current += self.totalSampleCount-startOfCarrier;
        for (uint i=0; i<sampleNumber/self.totalSampleCount; i++) {
            memcpy(current, _carrierSamples, self.totalSampleCount * LBAudioSampleTypeSize);
            current += self.totalSampleCount;
        }
        memcpy(current, _carrierSamples, endOfCarrier * LBAudioSampleTypeSize);
        current += endOfCarrier;
    } else {
        memcpy(current, _carrierSamples+startOfCarrier, (endOfCarrier-startOfCarrier) * LBAudioSampleTypeSize);
        current += endOfCarrier-startOfCarrier;
        for (uint i=0; i<sampleNumber/self.totalSampleCount; i++) {
            memcpy(current, _carrierSamples+endOfCarrier, (self.totalSampleCount-endOfCarrier) * LBAudioSampleTypeSize);
            current += self.totalSampleCount-endOfCarrier;
            memcpy(current, _carrierSamples, endOfCarrier * LBAudioSampleTypeSize);
            current += endOfCarrier;
        }
    }
    
    for (UInt32 i = 0; i<sampleNumber; i++) {
        sourceSamples[i] = [self mixedValue1:sourceSamples[i] value2:carrierSamples4ThisTime[i]*self.bgMusicVolume];
    }

    free(carrierSamples4ThisTime);
    return sampleNumber;
}

#pragma mark -
#pragma mark  Private Methods

- (BOOL)getMixFilterInfoWithFilterPath:(NSString *)filterPath{
    NSURL *mixedFileURL = [NSURL fileURLWithPath:filterPath];
    
    AudioFileID audioFile = NULL;
    OSStatus error = AudioFileOpenURL((__bridge CFURLRef)mixedFileURL, kAudioFileReadPermission, 0, &audioFile);
    if (error) {
        NSLog(@"open mixed file:%d",(int)error);
        return NO;
    }
    UInt64 filePackets;
    UInt32 propertySize = sizeof(filePackets);
    error = AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propertySize, &filePackets);
    if (error) {
        NSLog(@"read carrier file property (AudioDataPacketCount):%d",(int)error);
        AudioFileClose(audioFile);
        return NO;
    }
    
    UInt32 filePacketCount = (UInt32)filePackets;//做了强转

    self.carrierSamples = (LBAudioSampleType *)malloc(filePacketCount * LBAudioSampleTypeSize);
    
    error = AudioFileReadPackets(audioFile, NO, &_totalSampleCount, NULL, 0, &filePacketCount, _carrierSamples);
    
    self.totalSampleCount /= LBAudioSampleTypeSize;
    
    if (error) {
        NSLog(@"read carrier file:%d",(int)error);
        AudioFileClose(audioFile);
        free(_carrierSamples);
        return NO;
    }
    NSLog(@"read carrier samples:%ld",self.totalSampleCount);
    AudioFileClose(audioFile);
    return YES;
}

@end
