//
//  LBRemoteMusicViewController.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-6.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBRemoteMusicViewController.h"
#import "LBViewController.h"

@interface LBRemoteMusicViewController ()

@end

@implementation LBRemoteMusicViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dataSoure = [[NSMutableArray alloc]initWithObjects:
                  [NSDictionary dictionaryWithObjectsAndKeys:@"温柔", @"song", @"五月天", @"artise", @"http://y1.eoews.com/assets/ringtones/2012/5/18/34049/oiuxsvnbtxks7a0tg6xpdo66exdhi8h0bplp7twp.mp3", @"url", nil],
                  [NSDictionary dictionaryWithObjectsAndKeys:@"今天", @"song", @"刘德华", @"artise", @"http://y1.eoews.com/assets/ringtones/2012/5/18/34045/hi4dwfmrxm2citwjcc5841z3tiqaeeoczhbtfoex.mp3", @"url", nil],
                  [NSDictionary dictionaryWithObjectsAndKeys:@"K歌之王", @"song", @"陈奕迅", @"artise", @"http://y1.eoews.com/assets/ringtones/2012/5/17/34031/axiddhql6nhaegcofs4hgsjrllrcbrf175oyjuv0.mp3", @"url", nil],
                  [NSDictionary dictionaryWithObjectsAndKeys:@"知足", @"song", @"五月天", @"artise", @"http://y1.eoews.com/assets/ringtones/2012/5/17/34016/eeemlurxuizy6nltxf2u1yris3kpvdokwhddmeb0.mp3", @"url", nil],
                  [NSDictionary dictionaryWithObjectsAndKeys:@"桔子香水", @"song", @"任贤齐", @"artise", @"http://y1.eoews.com/assets/ringtones/2012/6/29/36195/mx8an3zgp2k4s5aywkr7wkqtqj0dh1vxcvii287a.mp3", @"url", nil],
                  nil];
}

-(NSInteger)numberOfRowsInSection:(NSInteger)section{
    return [self.dataSoure count];
}

-(UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    NSDictionary *item = self.dataSoure[indexPath.row];
    cell.textLabel.text = [item objectForKey:@"song"];
    return cell;
}

-(void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *item = self.dataSoure[indexPath.row];    
    LBViewController *viewController = [[LBViewController alloc] initWithUrl:[NSURL URLWithString:[item objectForKey:@"url"]] filePath:nil];
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
