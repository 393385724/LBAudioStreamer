//
//  LBMixAudioFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/16.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/**
 混合滤镜
 */
#import "LBBaseAudioFilter.h"

@interface LBMixAudioFilter : LBBaseAudioFilter

@property (nonatomic, assign) CGFloat bgMusicVolume;

- (instancetype)initWithFilterPath:(NSString *)filterPath bgMusicVolume:(CGFloat)bgMusicVolume;

@end
