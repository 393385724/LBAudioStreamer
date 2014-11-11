//
//  LBAudioStreamMetaCache.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioStreamMetaCache.h"

@interface LBAudioStreamMetaCache ()

@property (nonatomic, copy) NSString *metaCachePath;

@end

@implementation LBAudioStreamMetaCache

- (instancetype) initWithMetaCachePath:(NSString *)metaCachePath{
    self = [super init];
    if (self) {
        self.metaCachePath = metaCachePath;
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:metaCachePath];
        if (!dict) {
            self.rangeArray = [NSMutableArray arrayWithCapacity:1];
        } else {
            self.contentLength = dict[@"Content-Length"];
            self.rangeArray = [dict[@"ranges"] mutableCopy];
        }
    }
    return self;
}


- (NSUInteger)updateRangeWithLocation:(unsigned long long)location
                               length:(NSUInteger)length{
    BOOL found = NO;
    
    NSUInteger dataLen = length;
    
    for (int i=0; i<self.rangeArray.count; i++) {
        @autoreleasepool {
            NSArray *range = self.rangeArray[i];
            NSUInteger rangeStart = [range[0] unsignedIntegerValue];
            NSUInteger rangeEnd = [range[1] unsignedIntegerValue];
            
            if (rangeStart >= location + length) { //将要缓存的在当前range左边
                range = @[@(location), @(rangeEnd)];
                [self.rangeArray replaceObjectAtIndex:i withObject:range];
                found = YES;
            } else if (rangeEnd == location) { //将要缓存的在当前range右边
                range = @[@(rangeStart), @(location + length)];
                [self.rangeArray replaceObjectAtIndex:i withObject:range];
                found = YES;
            }
        }
    }
    
    if (!found) {
        [self.rangeArray addObject:@[@(location), @(location + length)]];
        [self updateMetaCache];
    }
    return dataLen;
}


- (void)updateMetaCache{
    //由低到高排序
    [self.rangeArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSArray *array1 = obj1;
        NSArray *array2 = obj2;
        return [array1[0] compare:array2[0]];
    }];
    
    //合并有交集的range
    NSArray *preRange = nil;
    NSArray *curRange = nil;
    for (int i=1; i<self.rangeArray.count; i++) {
        @autoreleasepool {
            preRange = self.rangeArray[i-1];
            curRange = self.rangeArray[i];
            if ([curRange[0] unsignedIntegerValue] >= [preRange[0] unsignedIntegerValue] &&
                [curRange[1] unsignedIntegerValue] >= [preRange[1] unsignedIntegerValue] &&
                [curRange[0] unsignedIntegerValue] <= [preRange[1] unsignedIntegerValue]) {
                [self.rangeArray removeObject:preRange];
                [self.rangeArray removeObject:curRange];
                [self.rangeArray insertObject:@[preRange[0], curRange[1]] atIndex:i-1];
                continue;
            }
        }
    }
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:self.contentLength, @"Content-Length",self.rangeArray, @"ranges", nil];
    [dict writeToFile:self.metaCachePath atomically:YES];
}


@end
