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
<AVCaptureFileOutputRecordingDelegate>

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIButton *shutterButton;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;

@property (nonatomic, strong) AVCaptureSession* session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;
@property (nonatomic, strong) AVCaptureDevice* currentDevice;
@property (nonatomic, strong) AVCaptureDeviceInput* currentDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput* imageOutput;

@property (nonatomic, strong) dispatch_queue_t cameraQueue;

@property (nonatomic) BOOL isDeviceAuthorized;

@property (nonatomic, strong) CameraSettings* cameraSettings;

@end


@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.cameraQueue = dispatch_queue_create("CameraQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(self.cameraQueue, ^{
        
        [self requestDeviceAuthorization];
        
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = AVCaptureSessionPresetPhoto;
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.previewView.layer insertSublayer:self.previewLayer atIndex:0];
        });
        
        [self toggleCameraDevice];
        
        NSError* error = nil;
        self.currentDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.currentDevice error:&error];
        
        if (error) {
            NSLog(@"%@", error);
        }
        
        if ([self.session canAddInput:self.currentDeviceInput]) {
            [self.session addInput:self.currentDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self.previewLayer connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            });
        }
        
        // Output
        self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
        [self.imageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        if ([self.session canAddOutput:self.imageOutput]) {
            [self.session addOutput:self.imageOutput];
        }
        
    });
    
    // TODO: temp
    self.shutterButton.backgroundColor = [UIColor redColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
//    [self becomeFirstResponder];  // To receive shaking event
    
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
    dispatch_async(self.cameraQueue, ^{
        [[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[self.previewLayer connection] videoOrientation]];
        
    });
}

- (void)resetCameraSettings
{
    // call after toggle camera to clear out any stored settings
    self.cameraSettings = [[CameraSettings alloc] init];
    
    // TODO: update UI one by one
    [self resetFlashButton];
}

- (void)resetFlashButton
{
    if ([self.currentDevice hasFlash]) {
        self.flashButton.enabled = YES;
        
        [self setFlashMode:self.cameraSettings.flashMode];
    }
    else {
        self.flashButton.enabled = NO;
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
            
        default:
            break;
    }
    self.cameraSettings.flashMode = newMode;
    
    [self setFlashMode:self.cameraSettings.flashMode];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    if ([self.currentDevice hasFlash] && [self.currentDevice isFlashModeSupported:flashMode]) {
        NSError* error = nil;
        if ([self.currentDevice lockForConfiguration:&error]) {
            [self.currentDevice setFlashMode:flashMode];
            [self.currentDevice unlockForConfiguration];
        }
        else {
            
        }
    }
}

#pragma mark - Shake Motion Handler

//- (BOOL)canBecomeFirstResponder
//{
//    return YES;
//}

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
    self.currentDevice = newDevice;
    
    [self resetCameraSettings];
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

