//
//  LBCatAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBCatAudioFilter.h"

@implementation LBCatAudioFilter

- (instancetype)init{
    self = [super init];
    if (self) {
        self.pitchSemiTones = 6.0;
        self.rateChange = 0.0015;
    }
    return self;
}

@end
