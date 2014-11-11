//
//  NSString+AudioPlayer.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (AudioPlayer)

- (NSString *)md5String;

+ (NSString *)papaAudioCacheDirectory;

+ (NSString *)papaAudioCachePath:(NSURL *)url hasType:(BOOL)type;

@end
