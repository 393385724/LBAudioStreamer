//
//  LBRecoderViewController.m
//  LBAudioPlayer
//
//  Created by lilingang on 14/12/12.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBRecoderViewController.h"
#import "LBAudioRecoder.h"

@interface LBRecoderViewController ()

@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *stopButton;

@property (nonatomic, strong) LBAudioRecoder *audioRecord;

@end

@implementation LBRecoderViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake(50, 100, 100, 100)];
    [self.recordButton setBackgroundColor:[UIColor redColor]];
    [self.recordButton addTarget:self action:@selector(recordButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.recordButton];
    
    self.stopButton = [[UIButton alloc] initWithFrame:CGRectMake(200, 100, 100, 100)];
    [self.stopButton setBackgroundColor:[UIColor redColor]];
    [self.stopButton addTarget:self action:@selector(stopButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopButton];
}

- (void)recordButtonAction{
    if (!self.audioRecord) {
//        self.audioRecord = [LBAudioRecoder alloc] initWithURL:<#(NSString *)#> settings:<#(NSDictionary *)#> error:<#(NSError *__autoreleasing *)#>
    }
    
}

- (void)stopButtonAction{
    
}

@end
