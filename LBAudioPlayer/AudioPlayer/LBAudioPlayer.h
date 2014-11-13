//
//  LBAudioPlayer.h
//  LBAudioPlayer
//
//  Created by lilingang on 14/11/5.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

FOUNDATION_EXTERN NSString *const AudioPlayerStateChangeNotification;

typedef NS_ENUM(NSUInteger, LBAudioStreamerState) {
    LBAudioStreamerStateIdle = 0,   //闲置状态
    LBAudioStreamerStateWaitting,   //正在等待
    LBAudioStreamerStatePlay,       //正在播放
    LBAudioStreamerStatePause,      //暂停
    LBAudioStreamerStateFlushing,   //等待最后数据播放完
    LBAudioStreamerStateStop,       //停止
    LBAudioStreamerStateError,      //出错了
};

@protocol LBAudioPlayerDelegate;

@interface LBAudioPlayer : NSObject

@property (nonatomic, weak) id<LBAudioPlayerDelegate> delegate;

@property (nonatomic) float volume; /* The volume for the sound.from 0.0 to 1.0. */

@property (nonatomic, assign) NSTimeInterval duration;
@property (readonly) NSTimeInterval currentTime;  //当前播放的时间,未播放为0,为什么老是差1s
@property (readonly) LBAudioStreamerState state;

/**Play Net Music*/
- (instancetype)initWithURL:(NSURL *)aUrl
             audioCachePath:(NSString *)cachePath;

/**Play iPod Music*/
- (instancetype)initWithAVURL:(NSURL *)aUrl;

/**Play Local Music*/
- (instancetype)initWithFilePath:(NSString *)filePath;

- (void)play;

- (void)seekToTime:(NSTimeInterval)seekTime;

- (void)paused;

- (void)stop;

@end



@protocol LBAudioPlayerDelegate <NSObject>

@optional

#if TARGET_OS_IPHONE

- (void)audioPlayerBeginInterruption:(LBAudioPlayer *)player;

- (void)audioPlayerEndInterruption:(LBAudioPlayer *)player;

#endif

@end