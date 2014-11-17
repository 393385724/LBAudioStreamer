//
//  LBRecoderFile.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/14.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBRecoderFile.h"
#import "LBAudioDefine.h"

@interface LBRecoderFile ()

@property (nonatomic, assign) AudioFileID recoderFile;

@end

@implementation LBRecoderFile

- (void)dealloc{
    [self closeAudioFile];
}

- (instancetype)initWithFilePath:(NSString *)filePath
                        fileType:(AudioFileTypeID)filetype
                          format:(AudioStreamBasicDescription)format
                           error:(NSError **) error{
    self = [super init];
    if (self) {
       CFURLRef fileURL = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);
       OSStatus status = AudioFileCreateWithURL(fileURL,
                                                filetype,
                                                &format,
                                                kAudioFileFlags_EraseFile,
                                                &_recoderFile);
        CFRelease(fileURL);
        if (status != noErr) {
            LBLog(@"AudioFileCreateWithURL: %@",OSStatusCode(status));
            *error = [NSError errorWithDomain:@"AudioFileCreate" code:100 userInfo:nil];
        }
    }
    return self;
}

- (BOOL)setMagicCookie:(NSData *)magicCookie magicCookieSize:(UInt32)cookieSize{
    UInt32 willEatTheCookie = false;
    OSStatus status = AudioFileGetPropertyInfo(self.recoderFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
    if (status == noErr && willEatTheCookie) {
        status = AudioFileSetProperty(self.recoderFile, kAudioFilePropertyMagicCookieData, cookieSize, [magicCookie bytes]);
        if (status != noErr) {
            LBLog(@"set audio file's magic cookie : %@",OSStatusCode(status));
            return NO;
        }
    } else {
        LBLog(@"AudioFileGetPropertyInfo Error or Read Only :%@",OSStatusCode(status));
    }
    return YES;
}


- (BOOL)writePackets:(UInt32)inNumPackets
          bufferData:(const void *)data
      bufferDataSize:(UInt32)dataSize
      startingPacket:(SInt64)inStartingPacket
        packetDesc:(const AudioStreamPacketDescription*)inPacketDesc{
   OSStatus status = AudioFileWritePackets(self.recoderFile,
                                           FALSE,
                                          dataSize,
                                          inPacketDesc,
                                          inStartingPacket,
                                          &inNumPackets,
                                          data);
    if (status != noErr) {
        LBLog(@"AudioFileWritePackets failed :%@",OSStatusCode(status));
        return NO;
    }
    return YES;
}

- (void)close{
    [self closeAudioFile];
}

#pragma mark -
#pragma mark  private Methods

- (void)closeAudioFile{
    if (self.recoderFile != NULL) {
        AudioFileClose(self.recoderFile);
    }
}

@end
