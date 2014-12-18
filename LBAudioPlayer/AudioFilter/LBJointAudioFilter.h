//
//  LBJointAudioFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/16.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/**
 前置后置滤镜
 inputFiles根据路径的顺序进行合并
 */

#import <Foundation/Foundation.h>

@interface LBJointAudioFilter : NSObject

// inputFiles - Array of Paths objects.
// outputPath - Path where the merged audio file needs to be stored.
// sampleRate - default 16000.0 按照input中最小的比特率来拼接
+ (BOOL)mergeAudioFilePaths:(NSArray *)inputFiles
                 outputPath:(NSString *)outputPath
          defaultSampleRate:(Float64)sampleRate;

@end
