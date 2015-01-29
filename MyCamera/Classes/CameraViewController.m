//
//  CameraViewController.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/24/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "CameraViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "CameraSettings.h"

@interface CameraViewController ()

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIButton *shutterButton;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *timerButton;
@property (weak, nonatomic) IBOutlet UIButton *bracketingButton;

@property (nonatomic, strong) AVCaptureSession* session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;
@property (nonatomic, strong) AVCaptureDevice* currentDevice;
@property (nonatomic, strong) AVCaptureDeviceInput* currentDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput* imageOutput;

@property (nonatomic, strong) dispatch_queue_t cameraQueue;

@property (nonatomic) BOOL isDeviceAuthorized;

@property (nonatomic, strong) CameraSettings* cameraSettings;

@end


// TODO: device authorization? what happens if user rejected?

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.cameraQueue = dispatch_queue_create("CameraQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(self.cameraQueue, ^{
        
        //[self requestDeviceAuthorization];
        
        // Session Creation
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = AVCaptureSessionPresetPhoto;
        
        
        // AVCaptureDevice and AVCaptureDeviceInput
        self.currentDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        NSError* error = nil;
        self.currentDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.currentDevice error:&error];
        
        if (error) {
            NSLog(@"%@ XM", error);
        }
        if ([self.session canAddInput:self.currentDeviceInput]) {
            [self.session addInput:self.currentDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self.previewLayer connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            });
        }
    
    
        // AVCaptureOutPut
        self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
        [self.imageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        if ([self.session canAddOutput:self.imageOutput]) {
            [self.session addOutput:self.imageOutput];
        }
        
        
        // PreviewLayer
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.frame = self.view.bounds;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.previewView.layer addSublayer:self.previewLayer];
        
        [self resetCameraSettings];

    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    dispatch_async(self.cameraQueue, ^{
        [self.session startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated
{
    dispatch_async(self.cameraQueue, ^{
        [self.session stopRunning];
    });
    
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate
{
    return NO; // TODO, will allow when UI support is in place
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (IBAction)shutterButtonTapped:(id)sender
{
    NSTimeInterval delay = [self.cameraSettings getTimerDelay];
    
    self.shutterButton.backgroundColor = [UIColor blueColor];
    [self performSelector:@selector(takePhoto) withObject:nil afterDelay:delay];
}

- (void)takePhoto
{
    self.shutterButton.backgroundColor = [UIColor redColor];
    if (self.cameraSettings.bracketingSetting == kBracketingSettingNoBracketing) {
        dispatch_async(self.cameraQueue, ^{
            [[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[self.previewLayer connection] videoOrientation]];
            [self.imageOutput captureStillImageAsynchronouslyFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                if (imageDataSampleBuffer) {
                    NSData* imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage* image = [[UIImage alloc] initWithData:imageData];
                    
                    [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
                        // TODO: should i do anything? confirmation?
                    }];
                }
                self.shutterButton.backgroundColor = [UIColor magentaColor];
            }];
        });
    }
    else {
        // Bracketing
    }
}

- (void)resetCameraSettings
{
    // call after toggle camera to clear out any stored settings
    self.cameraSettings = [[CameraSettings alloc] init];
    
    // TODO: update UI one by one
    [self resetFlashButton];
    [self resetTimerButton];
    [self resetBracketingButton];
}

- (void)resetFlashButton
{
    if ([self.currentDevice hasFlash]) {
        self.flashButton.enabled = YES;
        
        [self setFlashMode:self.cameraSettings.flashMode];
    }
    else {
        self.flashButton.enabled = NO;
        self.cameraSettings.flashMode = AVCaptureFlashModeOff;
        [self.flashButton setTitle:@"OFF" forState:UIControlStateNormal];
    }
}

- (void)resetTimerButton
{
    [self setTimer:self.cameraSettings.timerSetting];
}

- (void)resetBracketingButton
{
    // TODO: key-value ovserve maxBracketedCaptureStillImageCount to disable button whenever it becomes unavailable
    if ([self.imageOutput maxBracketedCaptureStillImageCount] >= 3) {
        self.bracketingButton.enabled = YES;
        
        [self setBracketingSetting:self.cameraSettings.bracketingSetting];
    }
    else {
        self.bracketingButton.enabled = NO;
        self.cameraSettings.bracketingSetting = kBracketingSettingNoBracketing;
        [self.bracketingButton setTitle:@"1" forState:UIControlStateNormal];
    }
}

- (IBAction)flashButtonTapped:(id)sender
{
    AVCaptureFlashMode newMode = AVCaptureFlashModeAuto;
    
    switch (self.cameraSettings.flashMode) {
        case AVCaptureFlashModeAuto:
            newMode = AVCaptureFlashModeOff;
            break;
            
        case AVCaptureFlashModeOff:
            newMode = AVCaptureFlashModeOn;
            break;
            
        case AVCaptureFlashModeOn:
            newMode = AVCaptureFlashModeAuto;
            break;
    }
    
    [self setFlashMode:newMode];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    if (self.cameraSettings.flashMode != flashMode) {
        self.cameraSettings.flashMode = flashMode;
    }
    
    dispatch_async(self.cameraQueue, ^{
        if ([self.currentDevice hasFlash] && [self.currentDevice isFlashModeSupported:flashMode])
        {
            NSError* error = nil;
            if ([self.currentDevice lockForConfiguration:&error])
            {
                [self.currentDevice setFlashMode:flashMode];
                [self.currentDevice unlockForConfiguration];
                
                NSString* buttonTitle = nil;
                switch (flashMode) {
                    case AVCaptureFlashModeAuto:
                        buttonTitle = @"AUTO";
                        break;
                     
                    case AVCaptureFlashModeOff:
                        buttonTitle = @"OFF";
                        break;
                        
                    case AVCaptureFlashModeOn:
                        buttonTitle = @"ON";
                        break;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.flashButton setTitle:buttonTitle forState:UIControlStateNormal];
                });
            }
            else {
                // TODO: error handling
            }
        }
    });
}

- (IBAction)timerButtonTapped:(id)sender
{
    ShutterTimerSetting timer = -1;
    switch (self.cameraSettings.timerSetting) {
        case kShutterTimerImmediate:
            timer = kShutterTimerTwoSeconds;
            break;
            
        case kShutterTimerTwoSeconds:
            timer = kShutterTimerTenSeconds;
            break;
            
        case kShutterTimerTenSeconds:
            timer = kShutterTimerImmediate;
            break;
    }
    [self setTimer:timer];
}

- (void)setTimer:(ShutterTimerSetting)timer
{
    if (self.cameraSettings.timerSetting != timer) {
        self.cameraSettings.timerSetting = timer;
    }
    
    NSString* title;
    switch (self.cameraSettings.timerSetting) {
        case kShutterTimerImmediate:
            title = @"NT";
            break;
            
        case kShutterTimerTwoSeconds:
            title = @"2T";
            break;
            
        case kShutterTimerTenSeconds:
            title = @"10T";
            break;
    }
    [self.timerButton setTitle:title forState:UIControlStateNormal];
}

- (IBAction)bracketingButtonTapped:(id)sender
{
    BracketingSetting newSetting = kBracketingSettingNoBracketing;
    switch (self.cameraSettings.bracketingSetting) {
        case kBracketingSettingNoBracketing:
            newSetting = kBracketingSettingBurst;
            break;
            
        case kBracketingSettingBurst:
            newSetting = kBracketingSettingExposure;
            break;
            
        case kBracketingSettingExposure:
            newSetting = kBracketingSettingShutterSpeed;
            break;
            
        case kBracketingSettingShutterSpeed:
            newSetting = kBracketingSettingNoBracketing;
            break;
    }
    [self setBracketingSetting:newSetting];
}

- (void)setBracketingSetting:(BracketingSetting)bracketingSetting
{
    if (self.cameraSettings.bracketingSetting != bracketingSetting) {
        self.cameraSettings.bracketingSetting = bracketingSetting;
    }
    
    NSString* title = nil;
    switch (bracketingSetting) {
        case kBracketingSettingNoBracketing:
            title = @"1";
            break;
        
        case kBracketingSettingBurst:
            title = @"3B";
            break;
            
        case kBracketingSettingExposure:
            title = @"3E";
            break;
            
        case kBracketingSettingShutterSpeed:
            title = @"3S";
            break;
    }
    [self.bracketingButton setTitle:title forState:UIControlStateNormal];
}




#pragma mark - Shake Motion Handler

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        dispatch_async(self.cameraQueue, ^{
            [self toggleCameraDevice];
        });
    }
}

#pragma mark - Helper Methods

- (void)toggleCameraDevice
{
    dispatch_async(self.cameraQueue, ^{
        AVCaptureDevicePosition newPosition;
        if (!self.currentDevice || self.currentDevice.position == AVCaptureDevicePositionFront) {
            newPosition = AVCaptureDevicePositionBack;
        }
        else {
            newPosition = AVCaptureDevicePositionFront;
        }
        
        AVCaptureDevice* newDevice = nil;
        NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice* device in devices) {
            if (device.position == newPosition) {
                newDevice = device;
                break;
            }
        }
        if (!newDevice) {
            newDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        NSError* error = nil;
        AVCaptureDeviceInput* newInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:&error];
        if (error) {
            NSLog(@"%@ XM", error);
        }
        
        [self.session beginConfiguration];
        
        [self.session removeInput:self.currentDeviceInput];
        if ([self.session canAddInput:newInput]) {
            [self.session addInput:newInput];
            self.currentDeviceInput = newInput;
            self.currentDevice = newDevice;
        }
        else {
            [self.session addInput:self.currentDeviceInput];
        }
        [self.session commitConfiguration];
        
        [self resetCameraSettings];

    });
}

- (void)requestDeviceAuthorization
{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
            self.isDeviceAuthorized = YES;
        }
        else {
            // TODO: better way of blocking any further user behavior
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"MyCamera"
                                                                message:@"MyCamera needs your authorization to use the camera on your device. Please change your settings"
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
                
            });
            self.isDeviceAuthorized = NO;
        }
    }];
}



@end

