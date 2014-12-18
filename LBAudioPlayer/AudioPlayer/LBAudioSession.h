//
//  LBAudioSession.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/7.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LBAudioSession : NSObject

+ (LBAudioSession *)shareInstance;

- (BOOL)setActive:(BOOL)active error:(NSError **)outError;
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError;

/* set session category */
- (BOOL)setCategory:(NSString *)category error:(NSError **)outError;

/* set session category with options */
- (BOOL)setCategory:(NSString *)category withOptions: (AVAudioSessionCategoryOptions)options error:(NSError **)outError;

- (void)requestRecordPermission:(PermissionBlock)response;

@end
