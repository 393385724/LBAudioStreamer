//
//  LBBaseAudioFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/16.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//AudioSampleType  ios8 之后废弃 故重新定义 消除警告

#ifdef __IPHONE_8_0
typedef SInt16               LBAudioSampleType;
#else
typedef AudioSampleType      LBAudioSampleType;
#endif

#define AudioRecoderDefaultSampleRate       (16000)
#define AudioRecoderDefaultChannels         (1)

const static size_t LBAudioSampleTypeSize = sizeof(LBAudioSampleType);

@interface LBBaseAudioFilter : NSObject

- (UInt32)doFilter:(LBAudioSampleType *)sourceSamples sampleNumber:(UInt32)sampleNumber;

//处理两个音频数据混合
- (SInt32)mixedValue1:(LBAudioSampleType)value1 value2:(LBAudioSampleType)value2;

@end
