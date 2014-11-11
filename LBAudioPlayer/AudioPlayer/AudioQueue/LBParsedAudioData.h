//
//  LBParsedAudioData.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

/* 帧描述 */

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface LBParsedAudioData : NSObject

@property (readonly) NSData *data;
@property (readonly) AudioStreamPacketDescription packetDescription;

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription;

@end
