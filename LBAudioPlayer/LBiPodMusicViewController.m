//
//  LBiPodMusicViewController.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-6.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBiPodMusicViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "LBAudioPlayer.h"
#import "LBViewController.h"

@interface LBiPodMusicViewController ()
@property (nonatomic, strong) LBAudioPlayer *audioPlayer;
@end

@implementation LBiPodMusicViewController

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
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("iPodMediaInputQueue", NULL);
    dispatch_async(mediaInputQueue, ^{
        MPMediaQuery *query = [MPMediaQuery songsQuery];
        for (MPMediaItemCollection *conllection in query.collections) {
            for (MPMediaItem *item in conllection.items) {
                if ([[item valueForProperty:MPMediaItemPropertyMediaType] integerValue] == MPMediaTypeMusic) {
                    [self.dataSoure addObject:item];
                }
            }
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    });
}

-(NSInteger)numberOfRowsInSection:(NSInteger)section{
    return [self.dataSoure count];
}

-(UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    MPMediaItem *item = self.dataSoure[indexPath.row];
    NSString *songName = [item valueForProperty:MPMediaItemPropertyTitle];
    NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
    NSTimeInterval playDuration = [[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    cell.textLabel.text = [[songName stringByAppendingString:[NSString stringWithFormat:@"||%@",artist]]stringByAppendingString:[NSString stringWithFormat:@"%f",playDuration]];
    return cell;
}

-(void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    MPMediaItem *item = self.dataSoure[indexPath.row];
    NSURL *songUrl = [item valueForProperty:MPMediaItemPropertyAssetURL];
    LBViewController *viewController = [[LBViewController alloc] initWithUrl:songUrl];
    [self.navigationController pushViewController:viewController animated:YES];
}


@end
