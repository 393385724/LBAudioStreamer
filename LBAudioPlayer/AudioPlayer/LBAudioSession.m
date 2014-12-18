//
//  LBAudioSession.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/7.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioSession.h"
#import "LBAudioDefine.h"

@implementation LBAudioSession

SYNTHESIZE_SINGLETON_FOR_CLASS(LBAudioSession);

- (BOOL)setActive:(BOOL)active error:(NSError **)outError{
   return [[AVAudioSession sharedInstance] setActive:active error:outError];
}

- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError{
    return [[AVAudioSession sharedInstance] setActive:active withOptions:options error:outError];
}


- (BOOL)setCategory:(NSString *)category error:(NSError **)outError{
   return [[AVAudioSession sharedInstance] setCategory:category error:outError];
}

- (BOOL)setCategory:(NSString *)category withOptions: (AVAudioSessionCategoryOptions)options error:(NSError **)outError{
   return [[AVAudioSession sharedInstance] setCategory:category withOptions:options error:outError];
}

- (void)requestRecordPermission:(PermissionBlock)response{
    
    //over iOS 6
    [[AVAudioSession sharedInstance] requestRecordPermission:response];
    
}

@end
