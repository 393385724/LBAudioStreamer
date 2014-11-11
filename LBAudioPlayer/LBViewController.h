//
//  LBViewController.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-7-31.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVURLAsset;

@interface LBViewController : UIViewController

- (instancetype) initWithUrl:(NSURL *)url filePath:(NSString *)filePath;
- (instancetype) initWithUrl:(NSURL *)url;

@end
