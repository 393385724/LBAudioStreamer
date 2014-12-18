//
//  LBEchoFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBBaseAudioFilter.h"

@interface LBEchoFilter : LBBaseAudioFilter

- (instancetype)initWithVolumeDecreaseRate:(Float32)volumeDecreaseRate
                                    repeat:(UInt32)repeat
                                 delayTime:(Float32)delayTime;

@end
