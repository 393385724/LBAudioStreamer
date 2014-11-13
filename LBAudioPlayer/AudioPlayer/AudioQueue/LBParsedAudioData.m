//
//  LBParsedAudioData.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBParsedAudioData.h"
#import "LBAudioDefine.h"

@interface LBParsedAudioData ()

@property (nonatomic,strong) NSData *data;
@property (nonatomic,assign) AudioStreamPacketDescription packetDescription;

@end

@implementation LBParsedAudioData

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription{
    return [[[self class] alloc] initWithBytes:bytes
                             packetDescription:packetDescription];
}

- (instancetype)initWithBytes:(const void *)bytes
            packetDescription:(AudioStreamPacketDescription)packetDescription{
    if (bytes == NULL || packetDescription.mDataByteSize == 0){
        LBLog(@"bytes == NULL || packetDescription.mDataByteSize == 0");
        return nil;
    }
    self = [super init];
    if (self) {
        self.data = [NSData dataWithBytes:bytes length:packetDescription.mDataByteSize];
        self.packetDescription = packetDescription;
    }
    return self;
}

@end
