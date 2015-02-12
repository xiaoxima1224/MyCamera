//
//  CameraSettings.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/26/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "CameraSettings.h"

@interface CameraSettings ()

@property (nonatomic, strong) NSArray* timerDataArray;
@property (nonatomic, strong) NSArray* flashDataArray;
@property (nonatomic, strong) NSArray* bracketingDataArray;

@end

@implementation CameraSettings

- (id)init
{
    self = [super init];
    if (self) {
        self.flashMode = AVCaptureFlashModeAuto;
        self.timerSetting = kShutterTimerImmediate;
        self.bracketingSetting = kBracketingSettingNoBracketing;
        self.exposureCompensation = 0;
        self.isAutoFocus = YES;
        
        self.timerDataArray = @[@"NT", @"2S", @"10S"];
        self.flashDataArray = @[@"Off", @"On", @"Auto"];
        self.bracketingDataArray = @[@"1", @"3B", @"3E", @"3S"];
    }
    return self;
}

- (NSTimeInterval)getTimerDelay
{
    NSTimeInterval delay = 0;
    switch (self.timerSetting) {
        case kShutterTimerImmediate:
            delay = 0;
            break;
        case kShutterTimerTwoSeconds:
            delay = 2;
            break;
            
        case kShutterTimerTenSeconds:
            delay = 10;
            break;
    }
    return delay;
}


- (ShutterTimerSetting)timerSettingAtIndex:(NSInteger)index
{
    ShutterTimerSetting timerSetting;
    switch (index) {
        case 0:
            timerSetting = kShutterTimerImmediate;
            break;
        
        case 1:
            timerSetting = kShutterTimerTwoSeconds;
            break;
            
        case 2:
            timerSetting = kShutterTimerTenSeconds;
            break;
            
        default:
            break;
    }
    return timerSetting;
}

- (NSString*)timerSettingTitleAtIndex:(NSInteger)index
{
    return self.timerDataArray[index];
}

- (NSInteger)numberOfTimerSettings
{
    return [self.timerDataArray count];
}


- (AVCaptureFlashMode)flashModeAtIndex:(NSInteger)index
{
    AVCaptureFlashMode flashMode;
    switch (index) {
        case 0:
            flashMode = AVCaptureFlashModeOff;
            break;
            
        case 1:
            flashMode = AVCaptureFlashModeOn;
            break;
            
        case 2:
            flashMode = AVCaptureFlashModeAuto;
            break;
            
        default:
            break;
    }
    return flashMode;
}

- (NSString*)flashModeTitleAtIndex:(NSInteger)index
{
    return self.flashDataArray[index];
}

- (NSInteger)numberOfFlashModes
{
    return [self.flashDataArray count];
}

- (BracketingSetting)bracketingSettingAtIndex:(NSInteger)index
{
    return (BracketingSetting)index;
}

- (NSString*)bracketingSettingTitleAtIndex:(NSInteger)index
{
    return self.bracketingDataArray[index];
}

- (NSInteger)numberOfBracketingSettings
{
    return [self.bracketingDataArray count];
}



@end
