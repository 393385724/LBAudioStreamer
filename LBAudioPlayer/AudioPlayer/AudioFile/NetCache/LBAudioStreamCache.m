//
//  LBAudioStreamCache.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBAudioStreamCache.h"
#import "LBAudioStreamMetaCache.h"
#import "LBAudioStreamNetRequest.h"

#define LBDefaultAudioDataCacheFileEncryptorPassword (200)    //8位 加密解密密钥


@interface LBAudioStreamCache ()

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *filePath;

@property (nonatomic, strong) LBAudioStreamNetRequest *netRequest;
@property (nonatomic, strong) LBAudioStreamMetaCache *metaCache;
@property (nonatomic, strong) NSString *metaCachePath;

@property (nonatomic, strong) NSFileHandle *writerFileHandle;
@property (nonatomic, strong) NSFileHandle *readerFileHandle;

@property (nonatomic, assign) unsigned long long bytesOffset;

@property (nonatomic, assign) BOOL hasOpen;

@end

@implementation LBAudioStreamCache


+ (BOOL)isCacheCompletedForCacheDataPath:(NSString *)cacheDataPath{
    NSString *metaCachePath = [NSString stringWithFormat:@"%@.meta", cacheDataPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDataPath] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:metaCachePath]) {
        return NO;
    }
    
    LBAudioStreamMetaCache *meta = [[LBAudioStreamMetaCache alloc] initWithMetaCachePath:metaCachePath];
    //缓存完毕只会有一个range数组且start == end
    if (meta.rangeArray.count != 1) {
        return NO;
    }
    
    NSArray *range = meta.rangeArray[0];
    return [range[1] unsignedIntegerValue] == [meta.contentLength unsignedIntegerValue];
}

#pragma mark -
#pragma mark   Accessor

-(unsigned long long)contentLength{
    unsigned long long length = [self.metaCache.contentLength unsignedIntegerValue];
    return length;
}

#pragma mark -
#pragma mark LifeCycle

- (void)dealloc{
    [self.metaCache updateMetaCache];
    [self.writerFileHandle closeFile];
    [self.readerFileHandle closeFile];
}

- (instancetype)initWithURL:(NSURL *)url cachePath:(NSString *)filePath{
    self =[super init];
    if (self) {
        self.url= url;
        self.filePath = filePath;
        self.bytesOffset = 0;
        self.metaCachePath = [self.filePath stringByAppendingString:@".meta"];
        self.metaCache = [[LBAudioStreamMetaCache alloc] initWithMetaCachePath:self.metaCachePath];
        self.readerFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
        [self createFile];
    }
    return self;
}

- (NSData *)readDataOfLength:(NSUInteger)length isEOF:(BOOL *)isEOF error:(NSError **)error{
    __block NSData *data = nil;
    for (NSArray *aRange in self.metaCache.rangeArray) {
        unsigned long long startOffset = [aRange[0] unsignedLongLongValue];
        unsigned long long endOffset = [aRange[1] unsignedLongLongValue];
        
        if (startOffset <= self.bytesOffset && endOffset > self.bytesOffset) {
            //缓存中包含将要读取的数据，length长度以缓存长度为准
            [self.readerFileHandle seekToFileOffset:self.bytesOffset];
            data = [self.readerFileHandle readDataOfLength:MIN(length, (NSUInteger)(endOffset - self.bytesOffset))];
            break;
        }
    }
    //无数据 请求
    if ([data length] == 0) {
        if (!self.netRequest) {
            self.netRequest = [[LBAudioStreamNetRequest alloc] initWithURL:self.url];
            [self.netRequest openReadStreamWithbyteOffset:self.bytesOffset];
            
            __weak LBAudioStreamCache *weakSelf = self;
            self.netRequest.netContentLenBlock = ^(unsigned long long contentLength){
                [weakSelf updateMetaWithContentLength:contentLength];
            };
        }
        
        data = [self.netRequest readDataWithLength:length isEOF:isEOF error:error];
        
        if ([data length]) {
            [self writeCacheData:data fromOffset:self.bytesOffset];
            
        } else if(self.bytesOffset > self.contentLength){
            
            *error = [NSError errorWithDomain:@""code:1000 userInfo:nil];
        }
    } else {
        self.netRequest = nil;
    }
    self.bytesOffset += [data length];

    return data;
}

- (void)seekToFileOffset:(unsigned long long)offset{
    self.bytesOffset = offset;
}

#pragma mark -
#pragma mark  pravite Method

- (void)createFile{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.filePath]) {
        [fileManager createFileAtPath:self.filePath
                             contents:nil
                           attributes:nil];
    }
    
    if (![fileManager fileExistsAtPath:self.metaCachePath]) {
        [fileManager createFileAtPath:self.metaCachePath
                             contents:nil
                           attributes:nil];
    }
}

- (void)updateMetaWithContentLength:(unsigned long long)contentLength{
    self.metaCache.contentLength = @(contentLength);
    [ self.metaCache updateMetaCache];
}

- (void)writeCacheData:(NSData *)cacheData
            fromOffset:(unsigned long long)fromOffset{
    if (!self.writerFileHandle) {
        self.writerFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.filePath];
    }
    [self.writerFileHandle seekToFileOffset:fromOffset];
    //TODO: 防止重合 暂时未做
    [self.metaCache updateRangeWithLocation:fromOffset length:cacheData.length];
    [self.writerFileHandle writeData:cacheData];
}
@end