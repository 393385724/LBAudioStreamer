//
//  LBBaseAudioFilter.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/16.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBBaseAudioFilter.h"

@implementation LBBaseAudioFilter

- (UInt32)doFilter:(LBAudioSampleType *)sourceSamples sampleNumber:(UInt32)sampleNumber{
    NSAssert(false, @"必须子类来实现这个方法");
    //子类实现
    return sampleNumber;
}

- (SInt32)mixedValue1:(LBAudioSampleType)value1 value2:(LBAudioSampleType)value2{
    UInt8 bitOffset = 8 * LBAudioSampleTypeSize;
    SInt32 bitMax = pow(2, bitOffset);
    SInt32 bitMid = bitMax/2;
    
    SInt32 sValue = 0;
    SInt8 sign1 = (value1 == 0)? 0 : abs(value1)/value1;
    SInt8 sign2 = (value2 == 0)? 0 : abs(value2)/value2;
    
    if (sign1 == sign2){
        UInt32 tmp = ((value1 * value2) >> (bitOffset -1));
        
        sValue = value1 + value2 - sign1 * tmp;
        
        if (abs(sValue) >= bitMid){
            sValue = sign1 * (bitMid -  1);
        }
    }else{
        SInt32 tmpValue1 = value1 + bitMid;
        SInt32 tmpValue2 = value2 + bitMid;
        
        UInt32 tmp = ((tmpValue1 * tmpValue2) >> (bitOffset -1));
        
        if (tmpValue1 < bitMid && tmpValue2 < bitMid){
            sValue = tmp;
        }else{
            sValue = 2 * (tmpValue1  + tmpValue2 ) - tmp - bitMax;
        }
        sValue -= bitMid;
    }
    
    if (abs(sValue) >= bitMid){
        SInt8 sign = sValue == 0 ? 1 : abs(sValue)/sValue;
        
        sValue = sign * (bitMid -  1);
    }
    return sValue;
}


@end
