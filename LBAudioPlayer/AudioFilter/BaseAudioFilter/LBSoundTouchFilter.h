//
//  LBSoundTouchFilter.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/**
 变声基类滤镜 封装了soundTouch库
 Tempo(时间段)：在不影响声音音调的前提下改变音频播放的快、慢节奏。
 Pitch(关键指标)：在保持原有节奏（速度）的前提下改变音调；
 Playback Rate：同时改变节奏和音调。
 */

#import "LBBaseAudioFilter.h"

@interface LBSoundTouchFilter : LBBaseAudioFilter

// tempo property
@property (nonatomic, assign) float tempo;
@property (nonatomic, assign) float tempoChange;
// rate property
@property (nonatomic, assign) float rate;
@property (nonatomic, assign) float rateChange;
// pitch property
@property (nonatomic, assign) float pitch;
@property (nonatomic, assign) float pitchOctaves;
@property (nonatomic, assign) float pitchSemiTones;

// channels
// althought you could set the channel to 2 stereo,
// but by now in DDM we only use channel = 1 = mono
// plz be careful when you change channels
@property (nonatomic, assign) uint numChannels;
// sample rate - in DDM we use fixed sample rate
// so be careful when you change this
@property (nonatomic, assign) uint sampleRate;


@end
