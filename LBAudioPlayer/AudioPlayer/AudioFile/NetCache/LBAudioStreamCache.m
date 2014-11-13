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

@property (nonatomic, assign) BOOL hasCached;

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
    if (self.hasCached) {
        return  _contentLength;
    } else {
        return [self.metaCache.contentLength unsignedIntegerValue];
    }
}

#pragma mark -
#pragma mark LifeCycle

- (void)dealloc{
    if (!self.hasCached) {
        [self.metaCache updateMetaCache];  
    }
    [self.writerFileHandle closeFile];
    [self.readerFileHandle closeFile];
}

- (instancetype)initWithFilePath:(NSString *)filePath{
    return [self initWithURL:nil cachePath:filePath hasCached:YES];
}

- (instancetype)initWithURL:(NSURL *)url cachePath:(NSString *)filePath{
    return [self initWithURL:url cachePath:filePath hasCached:NO];
}

- (instancetype)initWithURL:(NSURL *)url cachePath:(NSString *)filePath hasCached:(BOOL)cached{
    self =[super init];
    if (self) {
        NSAssert(filePath, @"filePath 不能为nil");
        self.hasCached = cached;
        self.url= url;
        self.filePath = filePath;
        self.bytesOffset = 0;
        self.metaCachePath = [self.filePath stringByAppendingString:@".meta"];
        self.metaCache = [[LBAudioStreamMetaCache alloc] initWithMetaCachePath:self.metaCachePath];
        self.readerFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
        if (cached) {
            self.contentLength = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil] fileSize];
        } else {
            [self createFile];
        }
    }
    return self;
}

- (NSData *)readDataOfLength:(NSUInteger)length isEOF:(BOOL *)isEOF error:(NSError **)error{
    NSData *data = nil;
    if (self.hasCached) {
        data = [self readLocaDataOfLength:length isEOF:isEOF error:error];
    } else {
        data = [self readNetDataOfLength:length isEOF:isEOF error:error];
    }
    self.bytesOffset += [data length];
    return data;
}

- (void)seekToFileOffset:(unsigned long long)offset{
    if (self.hasCached) {
        [self.readerFileHandle seekToFileOffset:offset];
    }
    self.bytesOffset = offset;
}

- (void)closeNet{
    self.netRequest = nil;
}

- (NSData *)readLocaDataOfLength:(NSUInteger)length isEOF:(BOOL *)isEOF error:(NSError **)error{
    if (self.bytesOffset >= self.contentLength) {
        *isEOF = YES;
        return nil;
    }
    return [self.readerFileHandle readDataOfLength:length];
}

- (NSData *)readNetDataOfLength:(NSUInteger)length isEOF:(BOOL *)isEOF error:(NSError **)error{
    __block NSData *data = nil;
    for (NSArray *aRange in self.metaCache.rangeArray) {
        unsigned long long startOffset = [aRange[0] unsignedLongLongValue];
        unsigned long long endOffset = [aRange[1] unsignedLongLongValue];
        
        if (startOffset <= self.bytesOffset && endOffset > self.bytesOffset) {
            //缓存中包含将要读取的数据，length长度以缓存长度为准
            if (!self.readerFileHandle) {
                self.readerFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
            }
            [self.readerFileHandle seekToFileOffset:self.bytesOffset];
            data = [self.readerFileHandle readDataOfLength:MIN(length, (NSUInteger)(endOffset - self.bytesOffset))];
            data = [self decryptData:data];
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
            *error = [NSError errorWithDomain:@"流媒体数据超了"code:100 userInfo:nil];
        }
    } else {
        self.netRequest = nil;
    }
    return data;
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
    NSRange cutRange = [self.metaCache updateRangeWithLocation:fromOffset length:cacheData.length];
    
    if (cutRange.length > 0 && cutRange.length < [cacheData length] ) {
        //去重
        UInt8 *buffer = (UInt8 *)malloc(cutRange.length);
        [cacheData getBytes:buffer range:cutRange];
        cacheData = [NSData dataWithBytes:buffer length:cutRange.length];
    }
    
    cacheData = [self encryptData:cacheData];
    [self.writerFileHandle seekToFileOffset:fromOffset];
    [self.writerFileHandle writeData:cacheData];
}

#pragma mark -
#pragma mark   兼容啪啪  位移加密

-(NSData *)encryptData:(NSData *)data{
    if (data.length == 0) {
        return data;
    }
    UInt8 *bytes = (UInt8 *)malloc(data.length);
    for (int i=0; i<data.length; i++) {
        bytes[i] = ((UInt8 *)data.bytes)[i] ^ LBDefaultAudioDataCacheFileEncryptorPassword;
    }
    NSData *result = [NSData dataWithBytes:bytes length:data.length];
    free(bytes);
    return result;
}

-(NSData *)decryptData:(NSData *)data{
    return [self encryptData:data];
}

@end
