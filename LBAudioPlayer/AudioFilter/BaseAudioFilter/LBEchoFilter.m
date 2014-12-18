//
//  LBEchoFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBEchoFilter.h"

@interface LBEchoFilter ()

@property (nonatomic, assign) Float32 volumeDecreaseRate;//声音锐减因数
@property (nonatomic, assign) UInt32 repeat;  //声音叠加次数

@property (nonatomic, assign) UInt32 delaySampleCount;
@property (nonatomic, assign) UInt32 bufferSize;
@property (nonatomic, assign) LBAudioSampleType *buffer;

@end

@implementation LBEchoFilter

#pragma mark -
#pragma mark  Life Cycle

- (void)dealloc{
    free(_buffer);
}

- (instancetype)initWithVolumeDecreaseRate:(Float32)volumeDecreaseRate
                                    repeat:(UInt32)repeat
                                 delayTime:(Float32)delayTime{
    self = [super init];
    if (self) {
        self.volumeDecreaseRate = volumeDecreaseRate;
        self.repeat = repeat;
        
        self.delaySampleCount = delayTime * AudioRecoderDefaultSampleRate;
        self.bufferSize = self.delaySampleCount * self.repeat + AudioRecoderDefaultSampleRate;
        self.buffer = (LBAudioSampleType *)malloc(self.bufferSize * LBAudioSampleTypeSize);
    }
    return self;
}

#pragma mark -
#pragma mark  Public Methods

-(UInt32)doFilter:(LBAudioSampleType *)sourceSamples sampleNumber:(UInt32)sampleNumber{
    [self writeToBuffer:sourceSamples length:sampleNumber];
    for (int r = 1; r < self.repeat; r++) {
        NSInteger bufferIndex = self.bufferSize - sampleNumber - r*self.delaySampleCount;
        for (UInt32 i=0; i<sampleNumber; i++) {
            sourceSamples[i] = [self mixedValue1:sourceSamples[i] value2:self.buffer[bufferIndex]*[self volumeOfEchoForRepeat:r]];
            bufferIndex ++;
        }
    }
    return sampleNumber;
}

#pragma mark -
#pragma mark  Private Methods

- (Float32)volumeOfEchoForRepeat:(UInt32)aRepeat{
    return powf(self.volumeDecreaseRate, (Float32)aRepeat);
}

-(void)writeToBuffer:(LBAudioSampleType *)samples length:(UInt32)length{
    LBAudioSampleType *tmpBuffer = (LBAudioSampleType *)malloc(self.bufferSize*LBAudioSampleTypeSize);
    memcpy(tmpBuffer, self.buffer +length, (self.bufferSize - length)*LBAudioSampleTypeSize);
    memcpy(self.buffer, tmpBuffer, self.bufferSize*LBAudioSampleTypeSize);
    memcpy(self.buffer + self.bufferSize-length, samples, length*LBAudioSampleTypeSize);
    free(tmpBuffer);
}

@end
