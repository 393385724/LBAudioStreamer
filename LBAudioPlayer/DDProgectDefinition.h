//
//  DDProgectDefinition.h
//  TestDemo
//
//  Created by lilingang on 14/10/31.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#ifndef TestDemo_DDProgectDefinition_h
#define TestDemo_DDProgectDefinition_h

/**
 本地化
 */

#ifndef _
#define _(s) NSLocalizedString(s, nil)
#endif

/**
 LOG宏定义,debug和release
 */

#ifdef DEBUG
#define DDLog(format, ...) do {                                             \
fprintf(stderr, "<%s :[Line] %d> %s\n",                                     \
[[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String],  \
__LINE__, __func__);                                                        \
(NSLog)((format), ##__VA_ARGS__);                                           \
fprintf(stderr, "-------\n");                                               \
} while (0)
#else
#define DDLog(format,...)
#endif

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

//音频播放 错误码
#define OSStatusCode(status) [NSString stringWithFormat:@"OSStatus:%d, %c%c%c%c",\
(int)status,\
((char *)&status)[3],\
((char *)&status)[2],\
((char *)&status)[1],\
((char *)&status)[0]]

#endif
