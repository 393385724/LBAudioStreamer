//
//  LBAudioStreamNetRequest.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/10.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^NetRequestContentLengthBlock)(unsigned long long contentLength);

@interface LBAudioStreamNetRequest : NSObject

@property (nonatomic, copy) NetRequestContentLengthBlock netContentLenBlock;

- (instancetype)initWithURL:(NSURL *)url;

- (BOOL)openReadStreamWithbyteOffset:(unsigned long long)byteOffset;

- (NSData *)readDataWithLength:(NSUInteger)length
                         isEOF:(BOOL *)isEOF
                         error:(NSError **)error;
@end
