//
//  LBBaseViewController.h
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-6.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LBAudioPlayer.h"

@interface LBBaseViewController : UIViewController<LBAudioPlayerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataSoure;
@property (nonatomic, strong) LBAudioPlayer *audioPlayer;

- (NSInteger)numberOfRowsInSection:(NSInteger)section;

- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
@end
