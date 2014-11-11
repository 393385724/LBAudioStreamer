//
//  LBRootViewController.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-6.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBRootViewController.h"
#import "LBiPodMusicViewController.h"
#import "LBRemoteMusicViewController.h"

@interface LBRootViewController ()


@end

@implementation LBRootViewController

- (instancetype)init{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dataSoure = [[NSMutableArray alloc] initWithObjects:@"本地",@"网络", nil];
}



-(NSInteger)numberOfRowsInSection:(NSInteger)section{
    return [self.dataSoure count];
}

-(UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = self.dataSoure[indexPath.row];
    return cell;
}

-(void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (indexPath.row) {
        case 0://本地
        {
            LBiPodMusicViewController *ipod = [[LBiPodMusicViewController alloc] init];
            [self.navigationController pushViewController:ipod animated:YES];
        }
            break;
        case 1://网络
        {
            LBRemoteMusicViewController *remote = [[LBRemoteMusicViewController alloc] init];
            [self.navigationController pushViewController:remote animated:YES];
            
        }
            break;
        case 2:
        {
            
        }
            break;
            
        default:
            break;
    }
}

@end
