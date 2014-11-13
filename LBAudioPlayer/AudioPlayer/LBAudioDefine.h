//
//  LBAudioDefine.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/11.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#ifndef LBAudioPlayer_LBAudioDefine_h
#define LBAudioPlayer_LBAudioDefine_h

const int kAQdefaultBufferSize = 1024;

const int kNumAQBufs = 16;  //>=3 太小容易卡顿，太大耗内存


//音频播放 错误码
#define OSStatusCode(status) [NSString stringWithFormat:@"OSStatus:%d, %c%c%c%c",\
(int)status,\
((char *)&status)[3],\
((char *)&status)[2],\
((char *)&status)[1],\
((char *)&status)[0]]

/**
 单例初始化宏定义
 Usage:
 引入头文件
 SYNTHESIZE_SINGLETON_FOR_CLASS(ClassName);
 */
#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) \
\
+ (classname *)shareInstance \
{\
\
static dispatch_once_t pred; \
\
static classname *instance = nil; \
\
dispatch_once(&pred, ^{ \
\
instance = [[self alloc] init]; \
\
} \
\
);\
return instance; \
} \

/**
 LOG宏定义,debug和release
 */

#ifdef DEBUG
#define LBLog(format, ...) do {                                             \
fprintf(stderr, "<%s :[Line] %d> %s\n",                                     \
[[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String],  \
__LINE__, __func__);                                                        \
(NSLog)((format), ##__VA_ARGS__);                                           \
fprintf(stderr, "-------\n");                                               \
} while (0)
#else
#define LBLog(format,...)
#endif


#endif
