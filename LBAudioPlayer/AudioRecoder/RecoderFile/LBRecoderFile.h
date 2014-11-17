//
//  LBRecoderFile.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/14.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface LBRecoderFile : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath
                        fileType:(AudioFileTypeID)filetype
                          format:(AudioStreamBasicDescription)format
                           error:(NSError **) error;

- (BOOL)setMagicCookie:(NSData *)magicCookie magicCookieSize:(UInt32)cookieSize;

- (BOOL)writePackets:(UInt32)inNumPackets
          bufferData:(const void *)data
      bufferDataSize:(UInt32)dataSize
      startingPacket:(SInt64)inStartingPacket
          packetDesc:(const AudioStreamPacketDescription*)inPacketDesc;

- (void)close;

@end
