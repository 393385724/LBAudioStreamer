//
//  LBAudioStreamNetRequest.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#include <pthread.h>
#include <sys/time.h>
#import "LBAudioStreamNetRequest.h"
#import "LBAudioDefine.h"

#define NETWORK_TIMEOUT (60)

@interface LBAudioStreamNetRequest (){
    
    CFReadStreamRef readStream;
    CFStreamEventType streamEventType;
    pthread_cond_t pthreadCond;
    pthread_mutex_t pthreadMutex;
}

@property (nonatomic, copy) NSURL *audioURL;

@property (nonatomic, strong) NSDictionary *httpHeaders;

@property (nonatomic, assign) unsigned long long seekByteOffset;


- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType;
@end

#pragma mark -
#pragma mark CFReadStream Callback Function Implementations

//静态回调函数
static void ReadStreamCallBack(
                               CFReadStreamRef aStream,
                               CFStreamEventType eventType,
                               void* inClientInfo
                               ){
    LBAudioStreamNetRequest* audioStreamNetRequest = (__bridge LBAudioStreamNetRequest *)inClientInfo;
    [audioStreamNetRequest handleReadFromStream:aStream eventType:eventType];
}


@implementation LBAudioStreamNetRequest

- (void)dealloc{
    pthread_mutex_destroy(&pthreadMutex);
    pthread_cond_destroy(&pthreadCond);
    
    if (readStream) {
        CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFReadStreamClose(readStream);
        CFRelease(readStream);
        readStream = NULL;
    }
}

- (instancetype)initWithURL:(NSURL *)url{
    if (self = [super init]) {
        self.audioURL = url;
        pthread_mutex_init(&pthreadMutex, NULL);
        pthread_cond_init(&pthreadCond, NULL);
    }
    return self;
}

- (BOOL)openReadStreamWithbyteOffset:(unsigned long long)byteOffset{
    self.seekByteOffset = byteOffset;
    
    // 创建HTTP GET请求
    CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL,
                                                         (CFStringRef)@"GET",
                                                         (__bridge CFURLRef)self.audioURL,
                                                         kCFHTTPVersion1_1);
    // 从偏移位置开始
    if (self.seekByteOffset){
        NSString *range = [NSString stringWithFormat:@"bytes=%llu-", self.seekByteOffset];
        CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Range"),
                                         (__bridge CFStringRef)range);
    }
    
    // 创建读流媒体
    readStream = CFReadStreamCreateForHTTPRequest(NULL, message);
    CFRelease(message);
    
    Boolean shouldAutoredirect = CFReadStreamSetProperty(readStream,
                                                         kCFStreamPropertyHTTPShouldAutoredirect,
                                                         kCFBooleanTrue);
    if (!shouldAutoredirect){
        LBLog(@"Read stream Set property failed ---- kCFStreamPropertyHTTPShouldAutoredirect");
        return NO;
    }
    
    CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
    Boolean canHTTPProxy = CFReadStreamSetProperty(readStream,
                                                   kCFStreamPropertyHTTPProxy,
                                                   proxySettings);
    CFRelease(proxySettings);
    
    if (!canHTTPProxy){
        LBLog(@"Read stream Set property failed ---- kCFStreamPropertyHTTPProxy");
        return NO;
    }
    
//    //
//    // Handle SSL connections
//    //
//    if([[self.audioURL scheme] isEqualToString:@"https"]){
//        NSDictionary *sslSettings =
//        [NSDictionary dictionaryWithObjectsAndKeys:
//         (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
//         [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
//         [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
//         [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
//         [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
//         [NSNull null], kCFStreamSSLPeerName,
//         nil];
//        
//        Boolean canSSlSettings = CFReadStreamSetProperty(readStream,
//                                                         kCFStreamPropertySSLSettings,
//                                                         (__bridge CFTypeRef)(sslSettings));
//        if (!canSSlSettings){
//            NSLog(@"Read stream Set property failed ---- kCFStreamPropertySSLSettings");
//            return NO;
//        }
//    }
    
    // 开始读
    if (!CFReadStreamOpen(readStream)){
        CFRelease(readStream);
        LBLog(@"Read stream Open failed.");
        return NO;
    }
    
    // Set our callback function to receive the data
    CFStreamClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    Boolean canSetClient =	CFReadStreamSetClient(readStream,
                                                  kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
                                                  ReadStreamCallBack,
                                                  &context);
    if (!canSetClient) {
        LBLog(@"Read stream SetClient failed.");
        return NO;
    }
    CFReadStreamScheduleWithRunLoop(readStream,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopCommonModes);
    return YES;
}



- (NSData *)readDataWithLength:(NSUInteger)length
                         isEOF:(BOOL *)isEOF
                         error:(NSError **)error{
    
    pthread_mutex_lock(&pthreadMutex);
    
    struct timespec   ts;
    struct timeval    tp;
    gettimeofday(&tp, NULL);//要获得当前精确时间（1970年1月1日到现在的时间）
    /* Convert from timeval to timespec */
    ts.tv_sec  = tp.tv_sec;
    ts.tv_nsec = tp.tv_usec * 1000;
    ts.tv_sec += NETWORK_TIMEOUT;
    
    while (streamEventType == kCFStreamEventNone && !CFReadStreamHasBytesAvailable(readStream)) {
        int status = pthread_cond_timedwait(&pthreadCond, &pthreadMutex, &ts);
        if (status != 0 || status == ETIMEDOUT) {
            pthread_mutex_unlock(&pthreadMutex);
            return nil;
        }
    }
    
    UInt8 *buffer = (UInt8 *)malloc(length);
    long len = CFReadStreamRead(readStream, buffer, length);
    
    if (len == 0) {
        pthread_mutex_unlock(&pthreadMutex);
        free(buffer);
        *isEOF = YES;
        return nil;
    }
    
    if (len == -1) {
        pthread_mutex_unlock(&pthreadMutex);
        free(buffer);
        *error = [NSError errorWithDomain:@"流媒体数据读取失败" code:100 userInfo:nil];
        return nil;
    }
    
    if (!self.httpHeaders) {
        CFTypeRef message =
        CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
        self.httpHeaders = (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields((CFHTTPMessageRef)message);
        CFRelease(message);
        
        unsigned long long contentLength = (unsigned long long)[[self.httpHeaders objectForKey:@"Content-Length"] unsignedIntValue] + self.seekByteOffset;
        if (self.netContentLenBlock) {
            self.netContentLenBlock(contentLength);
        }
    }
    NSData *data = [NSData dataWithBytes:buffer length:len];
    free(buffer);
    streamEventType = kCFStreamEventNone;
    pthread_mutex_unlock(&pthreadMutex);
    
    return data;
}

#pragma mark -
#pragma mark  CFReadStreamClientCallBack

- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType{
    pthread_mutex_lock(&pthreadMutex);
    streamEventType = eventType;
    pthread_cond_signal(&pthreadCond);
    pthread_mutex_unlock(&pthreadMutex);
}

@end
