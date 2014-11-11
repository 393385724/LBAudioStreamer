//
//  LBAudioStreamCache.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LBAudioStreamCache : NSObject

@property (nonatomic, assign) unsigned long long contentLength;

+ (BOOL)isCacheCompletedForCacheDataPath:(NSString *)cacheDataPath;

- (instancetype)initWithURL:(NSURL *)url cachePath:(NSString *)filePath;

- (NSData *)readDataOfLength:(NSUInteger)length isEOF:(BOOL *)isEOF error:(NSError **)error;

- (void)seekToFileOffset:(unsigned long long)offset;


@end
