//
//  LBAudioStreamMetaCache.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LBAudioStreamMetaCache : NSObject

/*音频总长度*/
@property (nonatomic, strong) NSNumber *contentLength;

/*已经存储的每个缓存块Data起始位置和结束位置(PS:快进会导致出现多个不连续的range，正常播放只会有一个range)*/
@property (nonatomic, strong) NSMutableArray *rangeArray;

- (instancetype) initWithMetaCachePath:(NSString *)metaCachePath;

- (NSRange)updateRangeWithLocation:(unsigned long long)location
                               length:(NSUInteger)length;

- (void)updateMetaCache;

@end
