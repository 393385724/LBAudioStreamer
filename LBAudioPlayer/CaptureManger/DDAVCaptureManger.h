//
//  DDAVCaptureManger.h
//  PAPA
//
//  Created by lilingang on 14/12/2.
//  Copyright (c) 2014年 diandian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol DDAVCaptureMangerDelegate <NSObject>

- (void)DDAVCaptureMangerDelegateDidFinishCaptureStillImage:(UIImage *)image;

@end

@interface DDAVCaptureManger : NSObject

@property (nonatomic, weak) id<DDAVCaptureMangerDelegate> delegate;

@property (nonatomic, assign) CGRect preivewLayerRect;

@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;

- (void)preViewOnSuperView:(UIView *)superView preLayerRect:(CGRect)preLayerRect;

- (BOOL)hasFlash;

- (BOOL)hasMoreInputDevice;

- (BOOL)startRunning;

- (BOOL)stopRunning;

- (void)takePicture;

- (void)focusInPoint:(CGPoint)devicePoint;

- (void)swichFlash;

- (void)rotateCamera;

@end
