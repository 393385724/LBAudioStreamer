//
//  LBAccelerateAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAccelerateAudioFilter.h"

@implementation LBAccelerateAudioFilter

- (instancetype)init{
    self = [super init];
    if (self) {
        self.tempoChange = 100 * (1.6 - 1);
    }
    return self;
}

@end
