//
//  LBAudioMergerFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioMergerFilter.h"
#import <AudioToolbox/AudioToolbox.h>
#import "LBAudioDefine.h"

const int defaultSampleRate = 16000.0;

@implementation LBAudioMergerFilter

+ (BOOL)mergeAudioFilePaths:(NSArray *)inputFiles
                 outputPath:(NSString *)outputPath
          defaultSampleRate:(Float64)sampleRate{
    OSStatus                            status = noErr;
    AudioStreamBasicDescription         outputFileFormat;
    NSUInteger                          numberOfChannels    = 1;
    ExtAudioFileRef						outputAudioFileRef  = NULL;
    //获取merger文件的最小的比特率
    NSURL *outputURL = [NSURL URLWithString:outputPath];
    Float64 tmpRate = [self minmSampleRateWithInputFiles:inputFiles defaultSamplRate:sampleRate];
    if (tmpRate == 0) {
        LBLog(@"比特率获取失败");
        return NO;
    }
    
    [self setDefaultAudioFormatFlags:&outputFileFormat sampleRate:tmpRate numChannels:numberOfChannels];

    
    UInt32 flags = kAudioFileFlags_EraseFile;
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)outputURL, kAudioFileCAFType, &outputFileFormat, NULL, flags, &outputAudioFileRef);
    
    if (status){
        if (outputAudioFileRef){
            ExtAudioFileDispose(outputAudioFileRef);
        }
        LBLog(@"ExtAudioFileCreateWithURL: %@",OSStatusCode(status));
        return NO;
    }
    
    BOOL success = YES;
    for(NSString *inputPath in inputFiles){
        NSURL *inputURL = [NSURL URLWithString:inputPath];
        success =  [self writeAudioFileWithURL:inputURL
                         toAudioFileWithFormat:&outputFileFormat
                                 fileReference:outputAudioFileRef
                           andNumberOfChannels:numberOfChannels];
        if(!success){
            break;
        }
    }
    if (!success) {
        return NO;
    }
    return YES;
}

+ (BOOL)writeAudioFileWithURL:(NSURL *)inputURL
        toAudioFileWithFormat:(AudioStreamBasicDescription *)outputFileFormat
                fileReference:(ExtAudioFileRef)outputAudioFileRef
          andNumberOfChannels:(NSUInteger)numberOfChannels{
    OSStatus                            status              = noErr;
    AudioStreamBasicDescription			inputFileFormat;
    UInt32								thePropertySize     = sizeof(inputFileFormat);
    ExtAudioFileRef						inputAudioFileRef   = NULL;
    UInt8                               *buffer             = NULL;
    
    status = ExtAudioFileOpenURL((__bridge CFURLRef)inputURL, &inputAudioFileRef);
    if (status){
        if (inputAudioFileRef){
            ExtAudioFileDispose(inputAudioFileRef);
        }
        LBLog(@"ExtAudioFileOpenURL: %@",OSStatusCode(status));
        return NO;
    }
    
    bzero(&inputFileFormat, sizeof(inputFileFormat));
    status = ExtAudioFileGetProperty(inputAudioFileRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &inputFileFormat);
    if (status){
        if (inputAudioFileRef){
            ExtAudioFileDispose(inputAudioFileRef);
        }
        LBLog(@"ExtAudioFileOpenURL: %@",OSStatusCode(status));
        return NO;
    }
    
    status = ExtAudioFileSetProperty(inputAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(*outputFileFormat), outputFileFormat);
    if (status){
        if (inputAudioFileRef){
            ExtAudioFileDispose(inputAudioFileRef);
        }
        LBLog(@"ExtAudioFileSetProperty: %@",OSStatusCode(status));
        return NO;
    }
    
    size_t bufferSize = 4096;
    buffer = malloc(bufferSize);
    assert(buffer);
    
    AudioBufferList conversionBuffer;
    conversionBuffer.mNumberBuffers = 1;
    conversionBuffer.mBuffers[0].mNumberChannels = numberOfChannels;
    conversionBuffer.mBuffers[0].mData = buffer;
    conversionBuffer.mBuffers[0].mDataByteSize = bufferSize;
    BOOL success = YES;
    while (TRUE){
        UInt32 frameCount = INT_MAX;
        if (inputFileFormat.mBytesPerFrame > 0){
            frameCount = (conversionBuffer.mBuffers[0].mDataByteSize / inputFileFormat.mBytesPerFrame);
        }
        
        status = ExtAudioFileRead(inputAudioFileRef, &frameCount, &conversionBuffer);
        if (status){
            NSLog(@"ExtAudioFileRead: %@",OSStatusCode(status));
            success = NO;
            break;
        }
        
        if (frameCount == 0){
            break;
        }
        
        status = ExtAudioFileWrite(outputAudioFileRef, frameCount, &conversionBuffer);
        if (status){
            NSLog(@"ExtAudioFileWrite: %@",OSStatusCode(status));
            success = NO;
            break;
        }
    }

    if (buffer != NULL){
        free(buffer);
    }
    return success;
}


+ (Float64)minmSampleRateWithInputFiles:(NSArray *)inputFiles defaultSamplRate:(Float64)sampleRate{
    OSStatus  status = noErr;
    Float64 tmpRate = sampleRate ? sampleRate : defaultSampleRate;
    
    for (NSString *inputPath in inputFiles) {
        @autoreleasepool {
            NSURL *inputURL = [NSURL URLWithString:inputPath];
            ExtAudioFileRef	tmpAudioFileRef  = NULL;
            AudioStreamBasicDescription   tmpAudioFileFormat;
            UInt32	thePropertySize  = sizeof(tmpAudioFileFormat);
            status = ExtAudioFileOpenURL((__bridge CFURLRef)inputURL, &tmpAudioFileRef);
            if (status){
                LBLog(@"ExtAudioFileOpenURL: %@",OSStatusCode(status));
                tmpRate = 0;
                if (tmpAudioFileRef){
                    ExtAudioFileDispose(tmpAudioFileRef);
                }
                break;
            }
            
            bzero(&tmpAudioFileFormat, sizeof(tmpAudioFileFormat));
            status = ExtAudioFileGetProperty(tmpAudioFileRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &tmpAudioFileFormat);
            if (status){
                tmpRate = 0;
                LBLog(@"ExtAudioFileGetProperty: %@",OSStatusCode(status));
                if (tmpAudioFileRef){
                    ExtAudioFileDispose(tmpAudioFileRef);
                }
                break;
            }
            if (tmpAudioFileRef){
                ExtAudioFileDispose(tmpAudioFileRef);
            }
            tmpRate =  MIN(tmpRate, tmpAudioFileFormat.mSampleRate);
        }
    }
    return tmpRate;
}

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
