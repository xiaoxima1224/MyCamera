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
#import "QuarterWheelViewController.h"
#import "FlowerPickerViewController.h"


static void* exposureCompensationContext = &exposureCompensationContext;
static void* focusingContext = &focusingContext;


@interface CameraViewController () <FlowerPickerViewControllerDataSource, FlowerPickerViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIButton *shutterButton;


@property (nonatomic, weak) FlowerPickerViewController* timerPickerViewController;
@property (nonatomic, weak) FlowerPickerViewController* flashPickerViewController;
@property (nonatomic, weak) FlowerPickerViewController* bracketingPickerViewController;

@property (nonatomic, strong) DrawerViewController* exposureCompensationDrawer;
@property (nonatomic, strong) DrawerViewController* focusingDrawer;



@property (nonatomic, strong) AVCaptureSession* session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;
@property (nonatomic, strong) AVCaptureDevice* currentDevice;
@property (nonatomic, strong) AVCaptureDeviceInput* currentDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput* imageOutput;

@property (nonatomic, strong) dispatch_queue_t cameraQueue;

@property (nonatomic) BOOL isDeviceAuthorized;  //?

@property (nonatomic, strong) CameraSettings* cameraSettings;

@property (nonatomic, strong) UITapGestureRecognizer* autoFocusPointTapGR;
@property (nonatomic, strong) UIView* focusIndicator;

@end


// TODO: device authorization? what happens if user rejected?

@implementation CameraViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController* childViewController = segue.destinationViewController;
    if ([segue.identifier isEqualToString:@"timerPickerSegue"]) {
        self.timerPickerViewController = (FlowerPickerViewController*)childViewController;
        self.timerPickerViewController.dataSource = self;
        self.timerPickerViewController.delegate = self;
        self.timerPickerViewController.style = kFlowerPickerViewControllerStyle120Degrees;
        self.timerPickerViewController.preferredPetalRadius = 100;
    }
    else if ([segue.identifier isEqualToString:@"flashPickerSegue"]) {
        self.flashPickerViewController = (FlowerPickerViewController*)childViewController;
        self.flashPickerViewController.dataSource = self;
        self.flashPickerViewController.delegate = self;
        self.flashPickerViewController.style = kFlowerPickerViewControllerStyle120Degrees;
        self.flashPickerViewController.preferredPetalRadius = 100;
    }
    else if ([segue.identifier isEqualToString:@"bracketingPickerSegue"]) {
        self.bracketingPickerViewController = (FlowerPickerViewController*)childViewController;
        self.bracketingPickerViewController.dataSource = self;
        self.bracketingPickerViewController.delegate = self;
        self.bracketingPickerViewController.style = kFlowerPickerViewControllerStyle120Degrees;
        self.bracketingPickerViewController.preferredPetalRadius = 100;
    }
    
}

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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.previewView.layer addSublayer:self.previewLayer];
            [[self.previewLayer connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
        });
        
        
        
        // KVO
        [self addObserver:self forKeyPath:@"currentDevice.exposureTargetBias" options:NSKeyValueObservingOptionNew context:exposureCompensationContext];
        [self addObserver:self forKeyPath:@"currentDevice.adjustingFocus" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:focusingContext];
        
    });
    
    
    // Exposure slider
    self.exposureCompensationDrawer = [[DrawerViewController alloc] init];
    self.exposureCompensationDrawer.view.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.exposureCompensationDrawer.view.frame = CGRectMake(0, -350, 60, 400);
    self.exposureCompensationDrawer.isOpen = NO;
    [self.exposureCompensationDrawer.drawerButton setTitle:@"EC" forState:UIControlStateNormal];
    
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
    
    
    // Auto/Manual focusing and focus point slider
    self.focusingDrawer = [[DrawerViewController alloc] init];
    self.focusingDrawer.view.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.focusingDrawer.view.frame = CGRectMake(kDeviceWidth-60, -350, 60, 400);
    self.focusingDrawer.isOpen = NO;
    [self.focusingDrawer.drawerButton setTitle:@"Focus" forState:UIControlStateNormal];
    [self setAutoFocusMode:YES];
    
    [self addChildViewController:self.focusingDrawer];
    [self.view addSubview:self.focusingDrawer.view];
    [self.focusingDrawer didMoveToParentViewController:self];
    
    self.focusingDrawer.sliderValueDidChange = ^(CGFloat newValue) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf setFocusLength:newValue];
    };
    self.focusingDrawer.buttonTapped = ^ {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf focusDrawerButtonTapped];
        return;
        
        strongSelf.focusingDrawer.isOpen = !strongSelf.focusingDrawer.isOpen;
        if (strongSelf.focusingDrawer.isOpen) {
            [UIView animateWithDuration:0.2f animations:^{
                strongSelf.focusingDrawer.view.frame = CGRectMake(kDeviceWidth-60, 0, 60, 400);
            }];
            
        } else {
            [UIView animateWithDuration:0.2f animations:^{
                strongSelf.focusingDrawer.view.frame = CGRectMake(kDeviceWidth-60, -350, 60, 400);
            }];
        }
    };
    
    
    // TODO
    QuarterWheelViewController* wheel = [[QuarterWheelViewController alloc] init];
    wheel.view.frame = CGRectMake(kDeviceWidth-120, kDeviceHeight-60, 120, 60);
    [self addChildViewController:wheel];
    [self.view addSubview:wheel.view];
    [wheel didMoveToParentViewController:self];
    
    
    // Tap to focus
    self.autoFocusPointTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAutoFocusPointTapGR:)];
    [self.previewView addGestureRecognizer:self.autoFocusPointTapGR];
    
    
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

#pragma mark - Shutter button functionality

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

#pragma mark - Resets

- (void)resetCameraSettings
{
    // TODO: update UI one by one
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Reset flashPicker
        self.flashPickerViewController.enabled = [self.currentDevice hasFlash];
        [self flowerPicker:self.flashPickerViewController didSelectPetalAtIndex:0];
        
        // Reset timerPicker
        [self flowerPicker:self.timerPickerViewController didSelectPetalAtIndex:0];
        
        // Reset bracketingPicker
        // TODO: key-value ovserve maxBracketedCaptureStillImageCount to disable button whenever it becomes unavailable
        self.bracketingPickerViewController.enabled = ([self.imageOutput maxBracketedCaptureStillImageCount] >= 3);
        [self flowerPicker:self.bracketingPickerViewController didSelectPetalAtIndex:0];
    });

    [self resetExposureCompensation];
    [self resetFocusMode];
}


- (void)resetExposureCompensation
{
    self.exposureCompensationDrawer.drawerSlider.minimumValue = self.currentDevice.minExposureTargetBias;
    self.exposureCompensationDrawer.drawerSlider.maximumValue = self.currentDevice.maxExposureTargetBias;
    self.exposureCompensationDrawer.drawerSlider.value = 0;
    
    [self setExposureCompensation:self.cameraSettings.exposureCompensation];
}

- (void)resetFocusMode
{
    if ([self.currentDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
        self.focusingDrawer.drawerButton.enabled = YES;
        self.focusingDrawer.drawerSlider.enabled = YES;
    }
    else {
        self.focusingDrawer.drawerButton.enabled = NO;
        self.focusingDrawer.drawerSlider.enabled = NO;
    }
}

#pragma mark - Controls


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
            }
            else {
                // TODO: error handling
            }
        }
    });
}

- (void)setTimer:(ShutterTimerSetting)timer
{
    if (self.cameraSettings.timerSetting != timer) {
        self.cameraSettings.timerSetting = timer;
    }
}

- (void)setBracketingSetting:(BracketingSetting)bracketingSetting
{
    if (self.cameraSettings.bracketingSetting != bracketingSetting) {
        self.cameraSettings.bracketingSetting = bracketingSetting;
    }
    
    // Flash is only supported for single shot, not bracketing
    dispatch_async(dispatch_get_main_queue(), ^{
        self.flashPickerViewController.enabled = (self.cameraSettings.bracketingSetting == kBracketingSettingNoBracketing);
    });
    
    
    dispatch_async(self.cameraQueue, ^{
        
        NSArray* settingsArr = nil;
        BOOL shouldPrepareBuffer = YES;
        
        switch (bracketingSetting) {
            case kBracketingSettingNoBracketing:
            {
                shouldPrepareBuffer = NO;
            }
                break;
                
            case kBracketingSettingBurst:
            {
                settingsArr = @[
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0],
                                [AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0]];
            }
                break;
                
            case kBracketingSettingExposure:
            {
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
                // Can't prep here, since I'll be using the Manual bracketedSettings and the lighting condition will change between now and then
                shouldPrepareBuffer = NO;
            }
                break;
        }
        
        if (shouldPrepareBuffer && settingsArr) {
            self.cameraSettings.bracketingSettingsArr = settingsArr;
        }
        else {
            settingsArr = @[[AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:0]];
        }
        
        [self.imageOutput prepareToCaptureStillImageBracketFromConnection:[self.imageOutput connectionWithMediaType:AVMediaTypeVideo]
                                                            withSettingsArray:settingsArr
                                                            completionHandler:^(BOOL prepared, NSError *error) {
                                                                if (error) {
                                                                    // TODO, why error?
                                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                                        self.shutterButton.enabled = NO;
                                                                        self.shutterButton.backgroundColor = [UIColor lightGrayColor];
                                                                    });
                                                                    
                                                                    // maybe lock/unlock user interface? dim the screen?
                                                                }
                                                            }];
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

- (void)focusDrawerButtonTapped
{
    if (self.focusingDrawer.isOpen) {
        // Close the drawer if open, leave it manual
        self.focusingDrawer.isOpen = NO;
        [UIView animateWithDuration:0.2f animations:^{
            self.focusingDrawer.view.frame = CGRectMake(kDeviceWidth-60, -350, 60, 400);
        }];
    }
    else {
        // when closed, if manual, switch to auto
        if (!self.cameraSettings.isAutoFocus) {
            
            [self setAutoFocusMode:YES];
        }
        // if closed and auto, switch to manual and open the drawer
        else {
            
            [self setAutoFocusMode:NO];
            
            self.focusingDrawer.isOpen = YES;
            self.focusingDrawer.drawerSlider.value = self.currentDevice.lensPosition;
            
            [UIView animateWithDuration:0.2f animations:^{
                self.focusingDrawer.view.frame = CGRectMake(kDeviceWidth-60, 0, 60, 400);
            }];
        }
    }
}

- (void)setAutoFocusMode:(BOOL)isAutoFocus
{
    self.cameraSettings.isAutoFocus = isAutoFocus;
    [self.focusingDrawer.drawerButton setTitle:(isAutoFocus ? @"Auto" : @"Manual") forState:UIControlStateNormal];
    self.autoFocusPointTapGR.enabled = isAutoFocus;
    
    // AVCaptureDevice set for real
    AVCaptureFocusMode newMode = isAutoFocus ? AVCaptureFocusModeContinuousAutoFocus : AVCaptureFocusModeLocked;
    dispatch_async(self.cameraQueue, ^{
        if ([self.currentDevice isFocusModeSupported:newMode]) {
            NSError* error = nil;
            if ([self.currentDevice lockForConfiguration:&error]) {
                [self.currentDevice setFocusMode:newMode];
                [self.currentDevice unlockForConfiguration];
            }
        }
    });
}

- (void)setFocusLength:(CGFloat)newValue
{
    dispatch_async(self.cameraQueue, ^{
        NSError* error = nil;
        if ([self.currentDevice lockForConfiguration:&error]) {
            __weak typeof(self) weakSelf = self;
            [self.currentDevice setFocusModeLockedWithLensPosition:newValue completionHandler:^(CMTime syncTime) {
                __strong typeof(self) strongSelf = weakSelf;
                [strongSelf.currentDevice unlockForConfiguration];
            }];
        }
    });
}

#pragma mark - UIGestureRecognizer

- (void)onAutoFocusPointTapGR:(UITapGestureRecognizer*)singleTapGR
{
    CGPoint location = [singleTapGR locationInView:self.previewView];
    
    if (!self.focusIndicator) {
        self.focusIndicator = [[UIView alloc] init];
        self.focusIndicator.alpha = 0.3;
        self.focusIndicator.backgroundColor = UIColorWithRGB(25, 188, 188);
    }
    self.focusIndicator.frame = CGRectMake(location.x - 20, location.y - 20, 40, 40);
    [self.previewView addSubview:self.focusIndicator];
    
    
    if ([self.currentDevice isFocusPointOfInterestSupported]) {
        dispatch_async(self.cameraQueue, ^{
            NSError* error = nil;
            if ([self.currentDevice lockForConfiguration:&error]) {
                self.currentDevice.focusPointOfInterest = location;
                self.currentDevice.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNone;
                [self.currentDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                [self.currentDevice unlockForConfiguration];
            }
        });
    }
}

- (void)resetFocusIndicator
{
    if (self.focusIndicator.superview) {
        [self.focusIndicator removeFromSuperview];
    }
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
    else if (context == focusingContext)
    {
        if ([keyPath isEqualToString:@"currentDevice.adjustingFocus"]) {
            BOOL isFocusing = [[change objectForKey:@"new"] boolValue];
            BOOL wasFocusing = [[change objectForKey:@"old"] boolValue];
            if (wasFocusing && !isFocusing) {
                // Done focusing, get rid of the focusing indicator
                [self resetFocusIndicator];
            }
        }
    }
}

#pragma mark - FlowerPickerViewControllerDelegate & FlowerPickerViewControllerDataSource

- (void)flowerPicker:(FlowerPickerViewController *)flowerPicker didSelectPetalAtIndex:(NSInteger)index
{
    if (flowerPicker == self.flashPickerViewController) {
        
        AVCaptureFlashMode newMode = [self.cameraSettings flashModeAtIndex:index];
        [self setFlashMode:newMode];
        
        ((UILabel*)[((FlowerCarpelView*)flowerPicker.carpelView) viewWithTag:1]).text = [self.cameraSettings flashModeTitleAtIndex:index];
        
    }
    else if (flowerPicker == self.timerPickerViewController) {
        
        ShutterTimerSetting timer = [self.cameraSettings timerSettingAtIndex:index];
        [self setTimer:timer];
        
        ((UILabel*)[((FlowerCarpelView*)flowerPicker.carpelView) viewWithTag:1]).text = [self.cameraSettings timerSettingTitleAtIndex:index];
    }
    else if (flowerPicker == self.bracketingPickerViewController) {
        
        BracketingSetting bracketingSetting = [self.cameraSettings bracketingSettingAtIndex:index];
        [self setBracketingSetting:bracketingSetting];
        
        ((UILabel*)[((FlowerCarpelView*)flowerPicker.carpelView) viewWithTag:1]).text = [self.cameraSettings bracketingSettingTitleAtIndex:index];
    }
}

- (FlowerCarpelView*)carpelViewForFlowerPicker:(FlowerPickerViewController *)flowerPicker
{
    FlowerCarpelView* carpel = [[FlowerCarpelView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    UILabel* label = [[UILabel alloc] initWithFrame:carpel.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    label.text = @" ";
    label.tag = 1;
    carpel.backgroundColor = [UIColor whiteColor];
    [carpel.contentView addSubview:label];
    
    return carpel;
}

- (FlowerPetalView*)petalViewForFlowerPicker:(FlowerPickerViewController *)flowerPicker atIndex:(NSInteger)index
{
    FlowerPetalView* pedal = [[FlowerPetalView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    UILabel* label = [[UILabel alloc] initWithFrame:pedal.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [pedal.contentView addSubview:label];
    pedal.backgroundColor = [UIColor whiteColor];
    
    NSString* newPetalStr;
    if (flowerPicker == self.timerPickerViewController) {
        newPetalStr = [self.cameraSettings timerSettingTitleAtIndex:index];
    }
    else if (flowerPicker == self.flashPickerViewController) {
        newPetalStr = [self.cameraSettings flashModeTitleAtIndex:index];
    }
    else if (flowerPicker == self.bracketingPickerViewController) {
        newPetalStr = [self.cameraSettings bracketingSettingTitleAtIndex:index];
    }
    label.text = newPetalStr;
    
    return pedal;
}

- (NSInteger)numberOfPetals:(FlowerPickerViewController *)flowerPicker
{
    if (flowerPicker == self.timerPickerViewController) {
        return [self.cameraSettings numberOfTimerSettings];   
    }
    else if (flowerPicker == self.flashPickerViewController) {
        return [self.cameraSettings numberOfFlashModes];
    }
    else if (flowerPicker == self.bracketingPickerViewController) {
        return [self.cameraSettings numberOfBracketingSettings];
    }
    return 0;
}

- (CGSize)sizeOfPetalForFlowerPicker:(FlowerPickerViewController *)flowerPicker
{
    return CGSizeMake(35, 35);
}


@end

