//
//  LBStageAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBStageAudioFilter.h"

@implementation LBStageAudioFilter

- (instancetype) init{
    return [super initWithVolumeDecreaseRate:0.7 repeat:10 delayTime:0.1];
}

@end
