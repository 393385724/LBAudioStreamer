//
//  LBViewController.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-7-31.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBViewController.h"
#import <CommonCrypto/CommonDigest.h>
#import "LBAudioPlayer.h"
#import "LBAudioRecoder.h"

@interface LBViewController ()

@property (nonatomic, strong) LBAudioPlayer *audioPlayer;

@property (nonatomic, strong) LBAudioRecoder *audioRecoder;

@property (nonatomic, strong) UISlider *sliderView;

@property (nonatomic, strong) UILabel *timeLable;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) NSTimer *recoderTimer;

@property (nonatomic, strong) UILabel *stateLabel;;

@end

@implementation LBViewController

- (NSString *)md5String:(NSURL *)url {
    NSString *string = [NSString stringWithFormat:@"%@",url];
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
}

- (NSString *)papaCachePath:(NSURL *)url{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf",[self md5String:url]]];
}


- (void)dealloc{
    [self.audioPlayer stop];
    [self.audioRecoder stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype) initWithUrl:(NSURL *)url filePath:(NSString *)filePath{
    self = [super init];
    if (self) {
        if (url) {
            _audioPlayer = [[LBAudioPlayer alloc] initWithURL:url audioCachePath:[self papaCachePath:url]];
        } else {
            _audioPlayer = [[LBAudioPlayer alloc] initWithFilePath:filePath];
        }
    }
    return self;
}

- (instancetype) initWithUrl:(NSURL *)url;{
    self = [super init];
    if (self) {
        _audioPlayer = [[LBAudioPlayer alloc] initWithAVURL:url];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *playButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 64, 100, 100)];
    [playButton setTitle:@"播放" forState:UIControlStateNormal];
    [playButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playButton];
    
    UIButton *pauseButton = [[UIButton alloc] initWithFrame:CGRectMake(100, 64, 100, 100)];
    [pauseButton setTitle:@"暂停" forState:UIControlStateNormal];
    [pauseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [pauseButton addTarget:self action:@selector(pauseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pauseButton];
    
    UIButton *stopButton = [[UIButton alloc] initWithFrame:CGRectMake(200, 64, 100, 100)];
    [stopButton setTitle:@"停止" forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [stopButton addTarget:self action:@selector(stopButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopButton];
    
    self.sliderView = [[UISlider alloc] initWithFrame:CGRectMake(0, 200, 320, 20)];
    self.sliderView.backgroundColor = [UIColor redColor];
    self.sliderView.value = 0;
    [self.sliderView addTarget:self action:@selector(ChangeValue:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.sliderView];
    
    self.timeLable = [[UILabel alloc]initWithFrame:CGRectMake(0, 220, 320, 40)];
    self.timeLable.textColor = [UIColor blackColor];
    [self.view addSubview:self.timeLable];
    
    self.stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 300, 320, 40)];
    self.stateLabel.backgroundColor = [UIColor greenColor];
    [self.view addSubview:self.stateLabel];
    
    UIButton *recoderButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 360, 100, 100)];
    [recoderButton setTitle:@"录音" forState:UIControlStateNormal];
    [recoderButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [recoderButton addTarget:self action:@selector(RecoderButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recoderButton];
    
    UIButton *paseButton = [[UIButton alloc] initWithFrame:CGRectMake(100, 360, 100, 100)];
    [paseButton setTitle:@"暂停录音" forState:UIControlStateNormal];
    [paseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [paseButton addTarget:self action:@selector(paseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:paseButton];
    
    UIButton *recoderStopButton = [[UIButton alloc] initWithFrame:CGRectMake(200, 360, 100, 100)];
    [recoderStopButton setTitle:@"停止录音" forState:UIControlStateNormal];
    [recoderStopButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [recoderStopButton addTarget:self action:@selector(stopRecoderButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recoderStopButton];

    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerStateChange:) name:AudioPlayerStateChangeNotification object:nil];
    
//    NSString *recoderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recoder.caf"];
////    self.audioRecoder = [[LBAudioRecoder alloc] initWithURL:recoderPath settings:nil error:nil];
//    
//    self.audioPlayer = [[LBAudioPlayer alloc] initWithFilePath:recoderPath];
}


- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark -
#pragma mark recoder

- (void)RecoderButtonPressed{
    NSLog(@"RecoderButtonPressed");
    [self.audioRecoder record];
    self.recoderTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updatetime) userInfo:nil repeats:YES];
}

- (void)updatetime{
    NSLog(@"updatetime: %f",self.audioRecoder.currentTime);
}

- (void)paseButtonPressed{
    NSLog(@"paseButtonPressed");
    [self.audioRecoder pause];
}

- (void)stopRecoderButtonPressed{
    NSLog(@"stopRecoderButtonPressed");
    [self.audioRecoder stop];
}

#pragma mark -
#pragma mark  Play

- (void)playButtonPressed{
    NSLog(@"playButtonPressed");
    [self.audioPlayer play];
}

- (void)pauseButtonPressed{
    NSLog(@"pauseButtonPressed");
    [self.audioPlayer paused];
}

- (void)stopButtonPressed{
    NSLog(@"stopButtonPressed");
    [self.audioPlayer stop];
}

- (void)ChangeValue:(UISlider *)slider{
    NSLog(@"dsdsdsdsdsds%f",slider.value*self.audioPlayer.duration);
    [self.audioPlayer seekToTime:slider.value*self.audioPlayer.duration];
}

- (void)updateSlider{
    if (!self.sliderView.tracking) {
        self.sliderView.value = self.audioPlayer.currentTime / self.audioPlayer.duration;
    }
    self.timeLable.text = [NSString stringWithFormat:@"%f/%f",self.audioPlayer.currentTime,self.audioPlayer.duration];
}


- (void)audioPlayerStateChange:(NSNotification *)notification{
    if ([notification.object integerValue] == LBAudioStreamerStatePlay || [notification.object integerValue] == LBAudioStreamerStateFlushing ||[notification.object integerValue] == LBAudioStreamerStateWaitting ) {
        if (!self.timer.valid) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updateSlider) userInfo:nil repeats:YES]; 
        }
    } else {
        [self.timer invalidate];
    }
    NSString *text = @"";
    switch ([notification.object integerValue]) {
        case LBAudioStreamerStateIdle:{
            text = @"闲置";
        }
            break;
        case LBAudioStreamerStateWaitting:{
            text = @"等待中...";
        }
            break;
        case LBAudioStreamerStatePlay:{
            text = @"播放";
        }
            break;
        case LBAudioStreamerStatePause:{
            text = @"暂停";
        }
            break;
        case LBAudioStreamerStateFlushing:{
            text = @"最后清除";
        }
            break;
        case LBAudioStreamerStateStop:{
            [self updateSlider];
            text = @"停止";
        }
            break;
        case LBAudioStreamerStateError:{
            text = @"出错啦";
        }
            break;
        default:
            break;
    }
    self.stateLabel.textColor = [UIColor redColor];
    self.stateLabel.text = text;
}
@end
