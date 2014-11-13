//
//  LBAudioMixFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioMixFilter.h"
#import <AudioToolbox/AudioToolbox.h>
#import "LBAudioDefine.h"

@implementation LBAudioMixFilter



+ (void)setDefaultAudioFormatFlags:(AudioStreamBasicDescription*)audioFormatPtr
                        sampleRate:(Float64)sampleRate
                       numChannels:(NSUInteger)numChannels{
    
    bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    
    audioFormatPtr->mFormatID = kAudioFormatLinearPCM;
    audioFormatPtr->mSampleRate = sampleRate;
    audioFormatPtr->mChannelsPerFrame = numChannels;
    audioFormatPtr->mBytesPerPacket = 2 * numChannels;
    audioFormatPtr->mFramesPerPacket = 1;
    audioFormatPtr->mBytesPerFrame = 2 * numChannels;
    audioFormatPtr->mBitsPerChannel = 16;
    audioFormatPtr->mFormatFlags = kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
}

@end
