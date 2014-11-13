//
//  LBAudioMergerFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/13.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LBAudioMergerFilter : NSObject

// inputFiles - Array of Paths objects.
// outputPath - Path where the merged audio file needs to be stored.
// sampleRate - default 16000.0 按照input中最小的比特率来拼接
+ (BOOL)mergeAudioFilePaths:(NSArray *)inputFiles
                 outputPath:(NSString *)outputPath
          defaultSampleRate:(Float64)sampleRate;

@end
