//
//  LBAudioDefine.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/11.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#ifndef LBAudioPlayer_LBAudioDefine_h
#define LBAudioPlayer_LBAudioDefine_h

const int kAQdefaultBufferSize = 2048;

const int kNumAQBufs = 16;  //>=3 太小容易卡顿，太大耗内存


//音频播放 错误码
#define OSStatusCode(status) [NSString stringWithFormat:@"OSStatus:%d, %c%c%c%c",\
(int)status,\
((char *)&status)[3],\
((char *)&status)[2],\
((char *)&status)[1],\
((char *)&status)[0]]

#endif
