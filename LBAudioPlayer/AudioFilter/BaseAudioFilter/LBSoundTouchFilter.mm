//
//  LBSoundTouchFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/17.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBSoundTouchFilter.h"
#import "SoundTouch.h"

@interface LBSoundTouchFilter (){
    soundtouch::SoundTouch soundTouchEngine;
}

@end

@implementation LBSoundTouchFilter

#pragma mark -
#pragma mark  Accessor

- (void)setTempo:(float)aTempo {
    _tempo = aTempo;
    soundTouchEngine.setTempo( _tempo);
}

- (void)setTempoChange:(float)aTempoChange {
    _tempoChange = aTempoChange;
    soundTouchEngine.setTempoChange( _tempoChange);
}

- (void)setRate:(float)aRate {
    _rate = aRate;
    soundTouchEngine.setRate(_rate);
}

- (void)setRateChange:(float)aRateChange {
    _tempoChange = aRateChange;
    soundTouchEngine.setRateChange(_tempoChange);
}

- (void)setPitch:(float)aPitch {
    _pitch = aPitch;
    soundTouchEngine.setPitch(_pitch);
}

- (void)setPitchOctaves:(float)aPitchOctaves {
    _pitchOctaves = aPitchOctaves;
    soundTouchEngine.setPitchOctaves(_pitchOctaves);
}

- (void)setPitchSemiTones:(float)aPitchSemiTones {
    _pitchSemiTones = aPitchSemiTones;
    soundTouchEngine.setPitchSemiTones(_pitchSemiTones);
}

- (void)setNumChannels:(uint)aNumChannels {
    _numChannels = aNumChannels;
    soundTouchEngine.setChannels(_numChannels);
}

- (void)setSampleRate:(uint)aSampleRate {
    _sampleRate = aSampleRate;
    soundTouchEngine.setSampleRate(_sampleRate);
}

#pragma mark -
#pragma mark Life Cycle

- (instancetype)init{
    self = [super init];
    if (self) {
        [self initSoundTouch];
    }
    return self;
}

#pragma mark -
#pragma mark Public Methods

-(UInt32)doFilter:(LBAudioSampleType *)sourceSamples sampleNumber:(UInt32)sampleNumber{
    UInt32 samplesWritten  = 0;
    UInt32 samplesReturned = 0;
    
    soundTouchEngine.putSamples((soundtouch::SAMPLETYPE*)sourceSamples, (uint)sampleNumber);
    
    do {
        if (sampleNumber >= samplesWritten) {
            samplesReturned = soundTouchEngine.receiveSamples((soundtouch::SAMPLETYPE*)sourceSamples + samplesWritten, sampleNumber - samplesWritten);
        }
        samplesWritten += samplesReturned;
    } while (samplesReturned != 0);
    
    return samplesWritten;
}

#pragma mark -
#pragma mark  private Methods

- (void)initSoundTouch {
    
    soundTouchEngine.setSampleRate(AudioRecoderDefaultSampleRate);
    soundTouchEngine.setChannels(AudioRecoderDefaultChannels);
    
    soundTouchEngine.setTempoChange(0.0f);
    soundTouchEngine.setPitchSemiTones(0.0f);
    soundTouchEngine.setRateChange(0.0f);
    
    /// Enable/disable quick seeking algorithm in tempo changer routine
    /// (enabling quick seeking lowers CPU utilization but causes a minor sound
    ///  quality compromising)
    soundTouchEngine.setSetting(SETTING_USE_QUICKSEEK, TRUE);
    /// Enable/disable anti-alias filter in pitch transposer (0 = disable)
    soundTouchEngine.setSetting(SETTING_USE_AA_FILTER, TRUE);
    
    // In my research:
    // for best pitch shift effect:
    // sequence 40ms, seekingwindow 20ms\16ms, overlap 10ms\8ms.
    // zhangwei.
    soundTouchEngine.setSetting(SETTING_SEQUENCE_MS, 40);
    soundTouchEngine.setSetting(SETTING_SEEKWINDOW_MS, 16);
    soundTouchEngine.setSetting(SETTING_OVERLAP_MS, 8);
}


@end
