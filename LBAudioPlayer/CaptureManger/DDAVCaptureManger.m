//
//  DDAVCaptureManger.m
//  PAPA
//
//  Created by lilingang on 14/12/2.
//  Copyright (c) 2014年 diandian. All rights reserved.
//

#import "DDAVCaptureManger.h"
#import <ImageIO/ImageIO.h>
#import "UIImage+Resize.h"

@interface DDAVCaptureManger ()

@property (nonatomic, strong) UIView *superView;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property (nonatomic, strong) AVCaptureDevice             *captureDevice;

@property (nonatomic, strong) AVCaptureSession            *session;
//AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureDeviceInput        *deviceInput;
//AVCaptureDeviceInput对象是输入流
@property (nonatomic, strong) AVCaptureStillImageOutput   *stillImageOutput;
//照片输出流对象，当然我的照相机只有拍照功能，所以只需要这个对象就够了
@property (nonatomic, strong) AVCaptureVideoPreviewLayer  *previewLayer;
//预览图层，来显示照相机拍摄到的画面

@property (nonatomic, assign) BOOL  focusing;

@end

@implementation DDAVCaptureManger

#pragma mark -
#pragma mark Accessor

- (AVCaptureConnection *)captureConnection{
    //get connection
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    return videoConnection;
}

#pragma mark -
#pragma mark  LifeCycle

- (instancetype)init{
    self = [super init];
    if (self) {
        self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        [self initialSession];
    }
    return self;
}

- (void)preViewOnSuperView:(UIView *)superView preLayerRect:(CGRect)preLayerRect{
    self.superView = superView;
    self.preivewLayerRect = preLayerRect;
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.preivewLayerRect;
}

- (BOOL)hasFlash{
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    return [captureDevice hasFlash] && [captureDevice isFlashModeSupported:AVCaptureFlashModeOn];
}

- (BOOL)hasMoreInputDevice{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1;
}

- (BOOL)startRunning{
    if (self.session && !self.session.isRunning) {
        [self.superView.layer addSublayer:self.previewLayer];
        [self.session startRunning];
        return YES;
    }
    return NO;
}

- (BOOL)stopRunning{
    if (self.session.isRunning) {
        [self.previewLayer removeFromSuperlayer];
        [self.session stopRunning];
        return YES;
    }
    return NO;
}

- (void)takePicture{
    AVCaptureConnection *videoConnection = [self captureConnection];
    if ( nil == videoConnection) {
        NSLog(@"AVCaptureConnection 获取失败");
        return;
    }
    [videoConnection setVideoScaleAndCropFactor:1.0];
    
    UIImageOrientation cropedImageOrientation = self.captureDevice.position == AVCaptureDevicePositionFront? uiDeviceOrientation2imageOrientationMirrored([UIDevice currentDevice].orientation) : uiDeviceOrientation2imageOrientationWithRotate90([UIDevice currentDevice].orientation);

    
    __weak DDAVCaptureManger*weakSelf= self;
    //get UIImage
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:
     ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
         CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
         if (exifAttachments) {
//             NSLog(@"attachements: %@", exifAttachments);
         } else {
//             NSLog(@"no attachments");
         }
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];

         UIImage *originImage = [[UIImage alloc] initWithData:imageData];
         originImage = [UIImage imageWithCGImage:originImage.CGImage scale:1 orientation:cropedImageOrientation];
         
         CGFloat squareLength = CGRectGetWidth(self.preivewLayerRect);
         CGFloat headHeight = CGRectGetHeight(self.preivewLayerRect) - squareLength;
         CGFloat scale = 1.0;
         if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
             scale = [[UIScreen mainScreen] scale];
         }
         CGSize size = CGSizeMake(squareLength * scale, squareLength * scale);
         UIImage *scaledImage = [originImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:size interpolationQuality:kCGInterpolationHigh];
         CGRect cropFrame = CGRectMake((scaledImage.size.width - size.width) / 2, (scaledImage.size.height - size.height) / 2 + headHeight, size.width, size.height);
         UIImage *croppedImage = [scaledImage croppedImage:cropFrame];
         croppedImage = [croppedImage imageRotatedWithOrientation];

         if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(DDAVCaptureMangerDelegateDidFinishCaptureStillImage:)]) {
             [weakSelf.delegate DDAVCaptureMangerDelegateDidFinishCaptureStillImage:croppedImage];
         }         
     }];
}

- (void)focusInPoint:(CGPoint)devicePoint{
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
    if (self.focusing) {
        return;
    }
    
    self.focusing = YES;
    UIImageView *tapFocusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pub_tap_focus.png"]];
    tapFocusImageView.frame = CGRectMake(0, 0, 20, 20);
    tapFocusImageView.center = devicePoint;
    [self.superView addSubview:tapFocusImageView];
    
    [UIView animateWithDuration:0.5f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        tapFocusImageView.alpha = 0.3f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            tapFocusImageView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [tapFocusImageView removeFromSuperview];
            self.focusing = NO;
        }];
    }];
    
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)swichFlash{
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [captureDevice lockForConfiguration:nil];
    if (captureDevice.flashMode == AVCaptureFlashModeOn) {
        captureDevice.flashMode = AVCaptureFlashModeOff;
    }
    if (captureDevice.flashMode == AVCaptureFlashModeOff) {
        captureDevice.flashMode = AVCaptureFlashModeOn;
    }
    [captureDevice unlockForConfiguration];
}

- (void)rotateCamera{
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = [[self.deviceInput device] position];
    
    if (currentCameraPosition == AVCaptureDevicePositionBack){
        currentCameraPosition = AVCaptureDevicePositionFront;
    } else {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = [self cameraWithPosition:currentCameraPosition];
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
    
    if (newVideoInput != nil){
        [self.session beginConfiguration];
        
        [self.session removeInput:self.deviceInput];
        if ([self.session canAddInput:newVideoInput]){
            [self.session addInput:newVideoInput];
            self.deviceInput = newVideoInput;
        } else {
            [self.session addInput:self.deviceInput];
        }
        [self.session commitConfiguration];
    }
}

#pragma mark -
#pragma mark

- (void)initialSession{
    self.session = [[AVCaptureSession alloc] init];
    self.deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self hasMoreInputDevice] ?[self backCamera]:[self frontCamera] error:nil];
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
    //这是输出流的设置参数AVVideoCodecJPEG参数表示以JPEG的图片格式输出图片
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    //默认打开Flash
    self.captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([self hasFlash]) {
        [self.captureDevice lockForConfiguration:nil];
        self.captureDevice.flashMode = AVCaptureFlashModeOff;
        [self.captureDevice unlockForConfiguration];
    }
    
    if ([self.session canAddInput:self.deviceInput]) {
        [self.session addInput:self.deviceInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
}


- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}


- (AVCaptureDevice *)frontCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *)backCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

/**
 *  外部的point转换为camera需要的point(外部point/相机页面的frame)
 *
 *  @param viewCoordinates 外部的point
 *
 *  @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[self.session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *device = [self.deviceInput device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]){
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]){
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            } if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]){
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        } else {
            NSLog(@"%@", error);
        }
    });
}


@end
