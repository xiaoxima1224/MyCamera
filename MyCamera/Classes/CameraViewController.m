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
#import "DrawerViewController.h"


static void* exposureCompensationContext = &exposureCompensationContext;


@interface CameraViewController ()

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIButton *shutterButton;

@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *timerButton;
@property (weak, nonatomic) IBOutlet UIButton *bracketingButton;

@property (nonatomic, strong) DrawerViewController* exposureCompensationDrawer;


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
    
    self.cameraSettings = [[CameraSettings alloc] init];
    
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
        if (self.imageOutput.isStillImageStabilizationSupported) {
            self.imageOutput.automaticallyEnablesStillImageStabilizationWhenAvailable = YES;
        }
        if ([self.session canAddOutput:self.imageOutput]) {
            [self.session addOutput:self.imageOutput];
        }
        
        
        // PreviewLayer
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.frame = self.view.bounds;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.previewView.layer addSublayer:self.previewLayer];
        
        
        // KVO
        [self addObserver:self forKeyPath:@"currentDevice.exposureTargetBias" options:NSKeyValueObservingOptionNew context:exposureCompensationContext];
        
    });
    
    
    self.exposureCompensationDrawer = [[DrawerViewController alloc] init];
    self.exposureCompensationDrawer.view.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.exposureCompensationDrawer.view.frame = CGRectMake(0, -350, 60, 400);
    self.exposureCompensationDrawer.isOpen = NO;
    
    [self addChildViewController:self.exposureCompensationDrawer];
    [self.view addSubview:self.exposureCompensationDrawer.view];
    [self.exposureCompensationDrawer didMoveToParentViewController:self];

    __weak typeof(self) weakSelf = self;
    self.exposureCompensationDrawer.sliderValueDidChange = ^(CGFloat newValue) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf setExposureCompensation:newValue];
    };
    self.exposureCompensationDrawer.buttonTapped = ^ {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.exposureCompensationDrawer.isOpen = !strongSelf.exposureCompensationDrawer.isOpen;
        if (strongSelf.exposureCompensationDrawer.isOpen) {
            [UIView animateWithDuration:0.2f animations:^{
                strongSelf.exposureCompensationDrawer.view.frame = CGRectMake(0, 0, 60, 400);
            }];
            
        } else {
            [UIView animateWithDuration:0.2f animations:^{
                strongSelf.exposureCompensationDrawer.view.frame = CGRectMake(0, -350, 60, 400);
            }];
        }
    };
    
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
        
        [self resetCameraSettings];
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
                    [self storeImageToLibrary:imageDataSampleBuffer];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.shutterButton.backgroundColor = [UIColor magentaColor];
                });
                
            }];
        });
    }
    else if (self.cameraSettings.bracketingSetting == kBracketingSettingShutterSpeed) {
        // Shutter speed bracketing, need to calculate exposure manually now
        dispatch_async(self.cameraQueue, ^{
            CMTime currentShutterSpeed = self.currentDevice.exposureDuration;
            CMTime minShutterSpeed = self.currentDevice.activeFormat.minExposureDuration;
            CMTime maxShutterSpeed = self.currentDevice.activeFormat.maxExposureDuration;
            
            float currentISO = self.currentDevice.ISO;
            float minISO = self.currentDevice.activeFormat.minISO;
            float maxISO = self.currentDevice.activeFormat.maxISO;
            
            CMTime slowerShutterSpeed = CMTimeMaximum(CMTimeMultiplyByRatio(currentShutterSpeed, 1, 2), minShutterSpeed);
            float higherISO = MIN(currentISO * 2, maxISO);
            AVCaptureManualExposureBracketedStillImageSettings* slowerSetting = [AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:slowerShutterSpeed ISO:higherISO];
            
            CMTime fasterShutterSpeed = CMTimeMinimum(CMTimeMultiplyByRatio(currentShutterSpeed, 2, 1), maxShutterSpeed);
            float lowerISO = MAX(currentISO / 2, minISO);
            AVCaptureManualExposureBracketedStillImageSettings* fasterSetting = [AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:fasterShutterSpeed ISO:lowerISO];
            
            NSArray* settingsArr = @[slowerSetting,
                                     [AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:currentShutterSpeed ISO:currentISO],
                                     fasterSetting];
            
            [self.imageOutput captureStillImageBracketAsynchronouslyFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] withSettingsArray:settingsArr completionHandler:^(CMSampleBufferRef sampleBuffer, AVCaptureBracketedStillImageSettings *stillImageSettings, NSError *error) {
                if (sampleBuffer) {
                    [self storeImageToLibrary:sampleBuffer];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.shutterButton.backgroundColor = [UIColor magentaColor];
                });
            }];
        });
    }
    else {
        // Bursting and Exposure bracketing
        dispatch_async(self.cameraQueue, ^{
            [self.imageOutput captureStillImageBracketAsynchronouslyFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] withSettingsArray:self.cameraSettings.bracketingSettingsArr completionHandler:^(CMSampleBufferRef sampleBuffer, AVCaptureBracketedStillImageSettings *stillImageSettings, NSError *error) {
                if (sampleBuffer) {
                    [self storeImageToLibrary:sampleBuffer];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.shutterButton.backgroundColor = [UIColor magentaColor];
                });
            }];
        });
    }
}

- (void)storeImageToLibrary:(CMSampleBufferRef)imageBuffer
{
    NSData* imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageBuffer];
    UIImage* image = [[UIImage alloc] initWithData:imageData];
    
    [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
        // TODO: should i do anything? confirmation?
        
    }];
}

- (void)resetCameraSettings
{
    // TODO: update UI one by one
    [self resetFlashButton];
    [self resetTimerButton];
    [self resetBracketingButton];
    [self resetExposureCompensation];
}

- (void)resetFlashButton
{
    if ([self.currentDevice hasFlash]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flashButton.enabled = YES;
        });
        
        [self setFlashMode:self.cameraSettings.flashMode];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flashButton.enabled = NO;
            [self.flashButton setTitle:@"OFF" forState:UIControlStateNormal];
        });
        
        [self setFlashMode:AVCaptureFlashModeOff];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bracketingButton.enabled = YES;
        });
        
        [self setBracketingSetting:self.cameraSettings.bracketingSetting];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bracketingButton.enabled = NO;
            [self.bracketingButton setTitle:@"1" forState:UIControlStateNormal];
        });
        
        [self setBracketingSetting:kBracketingSettingNoBracketing];
    }
}

- (void)resetExposureCompensation
{
    self.exposureCompensationDrawer.drawerSlider.minimumValue = self.currentDevice.minExposureTargetBias;
    self.exposureCompensationDrawer.drawerSlider.maximumValue = self.currentDevice.maxExposureTargetBias;
    self.exposureCompensationDrawer.drawerSlider.value = 0;
    
    [self setExposureCompensation:self.cameraSettings.exposureCompensation];
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
        if ([self.currentDevice isFlashModeSupported:flashMode])
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timerButton setTitle:title forState:UIControlStateNormal];
    });
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
    
    // Flash is only supported for single shot, not bracketing
    dispatch_async(dispatch_get_main_queue(), ^{
        self.flashButton.enabled = (self.cameraSettings.bracketingSetting == kBracketingSettingNoBracketing);
    });
    
    
    dispatch_async(self.cameraQueue, ^{
        NSString* title = nil;
        NSArray* settingsArr = nil;
        BOOL shouldPrepareBuffer = YES;
        
        switch (bracketingSetting) {
            case kBracketingSettingNoBracketing:
            {
                title = @"1";
                
                shouldPrepareBuffer = NO;
            }
                break;
                
            case kBracketingSettingBurst:
            {
                title = @"3B";
                
                settingsArr = @[
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0]];
            }
                break;
                
            case kBracketingSettingExposure:
            {
                title = @"3E";
                
                CGFloat minBias = [self.currentDevice minExposureTargetBias];
                CGFloat maxBias = [self.currentDevice maxExposureTargetBias];
                settingsArr = @[
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:MAX(-2, minBias)],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:MIN(2, maxBias)]
                                ];
            }
                break;
                
            case kBracketingSettingShutterSpeed:
            {
                title = @"3S";
                
                // Can't prep here, since I'll be using the Manual bracketedSettings and the lighting condition will change between now and then
                shouldPrepareBuffer = NO;
            }
                break;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.bracketingButton setTitle:title forState:UIControlStateNormal];
        });
        
        if (shouldPrepareBuffer) {
            self.cameraSettings.bracketingSettingsArr = settingsArr;
            
            [self.imageOutput prepareToCaptureStillImageBracketFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] withSettingsArray:settingsArr completionHandler:^(BOOL prepared, NSError *error) {
                if (error) {
                    // TODO, why error?
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.shutterButton.enabled = NO;
                        self.shutterButton.backgroundColor = [UIColor lightGrayColor];
                    });
                    
                    // maybe lock/unlock user interface? dim the screen?
                }
            }];
        }
        else {
            [self.imageOutput prepareToCaptureStillImageBracketFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] withSettingsArray:@[[AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0], [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0]] completionHandler:^(BOOL prepared, NSError *error) {
                // TODO, why error?
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.shutterButton.enabled = NO;
                        self.shutterButton.backgroundColor = [UIColor lightGrayColor];
                    });
                    // maybe lock/unlock user interface? dim the screen?
                }
            }];
        }
    });
}

- (void)setExposureCompensation:(CGFloat)compensation
{
    if (self.cameraSettings.exposureCompensation != compensation) {
        self.cameraSettings.exposureCompensation = compensation;
    }
    
    dispatch_async(self.cameraQueue, ^{
        
        NSError* error;
        if ([self.currentDevice lockForConfiguration:&error]) {
            __weak typeof(self) weakSelf = self;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.exposureCompensationDrawer.drawerSlider.enabled = NO;
            });
            
            
            [self.currentDevice setExposureTargetBias:self.cameraSettings.exposureCompensation completionHandler:^(CMTime syncTime) {
                // TODO?
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf.currentDevice unlockForConfiguration];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf.exposureCompensationDrawer.drawerSlider.enabled = YES;
                });
            }];
        }
        else {
            NSLog(@"%@", error);
        }
    });
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
        
        
        self.cameraSettings = [[CameraSettings alloc] init];
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

#pragma mark - Key-Value Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == exposureCompensationContext)
    {
        if ([keyPath isEqualToString:@"currentDevice.exposureTargetBias"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.exposureCompensationDrawer.drawerSlider.value = [[change objectForKey:@"new"] floatValue]; // TODO: shouldn't need this
                NSString* valueStr = [NSString stringWithFormat:@"%.2f", [[change objectForKey:@"new"] floatValue]];
                [self.exposureCompensationDrawer.drawerButton setTitle:valueStr forState:UIControlStateNormal];
            });
        }
    }
}

@end

