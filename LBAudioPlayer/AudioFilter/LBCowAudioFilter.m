//
//  LBCowAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBCowAudioFilter.h"

@implementation LBCowAudioFilter

- (instancetype)init{
    self = [super init];
    if (self) {
        self.pitchSemiTones = -4.0;
        self.rateChange = -0.01;
    }
    return self;
}

@end
