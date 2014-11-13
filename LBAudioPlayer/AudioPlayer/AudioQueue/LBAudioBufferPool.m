//
//  LBAudioBufferFactory.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-4.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioBufferPool.h"
#import "LBParsedAudioData.h"
#import "LBAudioDefine.h"

@interface LBAudioBufferPool ()

@property (nonatomic, strong) NSMutableArray *bufferArray;

@property (nonatomic, assign) NSUInteger bufferPoolSize;

@end

@implementation LBAudioBufferPool

+ (LBAudioBufferPool *)bufferPool{
    return [[[self class] alloc] init];
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.bufferArray = [NSMutableArray arrayWithCapacity:0];
        self.bufferPoolSize = 0;
    }
    return self;
}

- (void)enqueueFromDataArray:(NSArray *)dataArray{
    for (LBParsedAudioData *parsedData in dataArray) {
        if ([parsedData isKindOfClass:[LBParsedAudioData class]]) {
            [self.bufferArray addObject:parsedData];
            self.bufferPoolSize += parsedData.data.length;
        }
    }
}

- (BOOL)isEmpty{
    return [self.bufferArray count] == 0;
}

- (NSData *)dequeueDataWithSize:(UInt32)bufferSize
                    packetCount:(UInt32 *)packetCount
                   descriptions:(AudioStreamPacketDescription **)descriptions{
    
    if (bufferSize == 0 || [self isEmpty]){
        LBLog(@"bufferSize == 0 || [self isEmpty]");
        return nil;
    }
    
    //计算需要数据帧个数
    for (int i = 0; i < self.bufferArray.count ; i++){
        LBParsedAudioData *block = self.bufferArray[i];
        NSUInteger dataLength = [block.data length];
        if (bufferSize >= dataLength){
            bufferSize -= dataLength;
            *packetCount = *packetCount + 1;
        } else {
            break;
        }
    }
    
    //填充buffer 以及package描述
    if (descriptions != NULL){
        *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * (*packetCount));
    }
    
    NSMutableData *bufferedData = [[NSMutableData alloc] init];
    
    for (int j = 0; j < *packetCount; ++j){
        LBParsedAudioData *block = self.bufferArray[j];
        if (descriptions != NULL){
            AudioStreamPacketDescription desc = block.packetDescription;
            desc.mStartOffset = [bufferedData length];
            (*descriptions)[j] = desc;
        }
        [bufferedData appendData:block.data];
    }
    
    NSRange removeRange = NSMakeRange(0, *packetCount);
    [self.bufferArray removeObjectsInRange:removeRange];
     self.bufferPoolSize -= bufferedData.length;
    return bufferedData;
}

- (void)clean{
    [self.bufferArray removeAllObjects];
    self.bufferPoolSize = 0;
}

@end
