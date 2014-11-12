//
//  AudioTest.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/12.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioTest : NSObject

+ (OSStatus)mixAudio:(NSString *)audioPath1
            andAudio:(NSString *)audioPath2
              toFile:(NSString *)outputPath
  preferedSampleRate:(float)sampleRate;

@end
