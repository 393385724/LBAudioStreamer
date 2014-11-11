//
//  LBBaseViewController.m
//  LBAudioStreamer
//
//  Created by lilingang on 14-8-6.
//  Copyright (c) 2014年 lilingang. All rights reserved.
//

#import "LBBaseViewController.h"

@interface LBBaseViewController ()<UITableViewDataSource,UITableViewDelegate>

@end

@implementation LBBaseViewController

- (instancetype)init{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    self.dataSoure = [[NSMutableArray alloc] init];
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section{
    return [self.dataSoure count];
}

- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self numberOfRowsInSection:section];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    return [self cellForRowAtIndexPath:indexPath];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self didSelectRowAtIndexPath:indexPath];
}


@end
