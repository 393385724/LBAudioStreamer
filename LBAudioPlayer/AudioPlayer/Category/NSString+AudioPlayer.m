//
//  NSString+AudioPlayer.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "NSString+AudioPlayer.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (AudioPlayer)

- (NSString *)md5String {
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
}

+ (NSString *)papaAudioCacheDirectory{
    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSString *dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AudioCache"];
    if (![fileManger fileExistsAtPath:dirPath]) {
        [fileManger createDirectoryAtPath:dirPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    return dirPath;
}

+ (NSString *)papaAudioCachePath:(NSURL *)url hasType:(BOOL)type{
    NSString *fileName = [[NSString stringWithFormat:@"%@",url] md5String];
    if (type) {
       fileName = [fileName stringByAppendingString:@".caf"];
    }
    return [[NSString papaAudioCacheDirectory] stringByAppendingPathComponent:fileName];
}
@end
