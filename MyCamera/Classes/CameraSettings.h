//
//  CameraSettings.h
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/26/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


typedef NS_ENUM(NSInteger, ShutterTimerSetting)
{
    kShutterTimerImmediate = 0,
    kShutterTimerTwoSeconds = 1,
    kShutterTimerTenSeconds = 2
};

typedef NS_ENUM(NSInteger, BracketingSetting)
{
    kBracketingSettingNoBracketing = 0,
    kBracketingSettingBurst = 1,
    kBracketingSettingExposure = 2,
    kBracketingSettingShutterSpeed = 3,
};

@interface CameraSettings : NSObject

@property (nonatomic) AVCaptureFlashMode flashMode;

@property (nonatomic) ShutterTimerSetting timerSetting;

@property (nonatomic) BracketingSetting bracketingSetting;
@property (nonatomic, strong) NSArray* bracketingSettingsArr;

@property (nonatomic) BOOL isAutoFocus;
@property (nonatomic) CGFloat lensPosition;

@property (nonatomic) CGFloat exposureCompensation;

- (NSTimeInterval)getTimerDelay;


- (ShutterTimerSetting)timerSettingAtIndex:(NSInteger)index;
- (NSString*)timerSettingTitleAtIndex:(NSInteger)index;
- (NSInteger)numberOfTimerSettings;

- (AVCaptureFlashMode)flashModeAtIndex:(NSInteger)index;
- (NSString*)flashModeTitleAtIndex:(NSInteger)index;
- (NSInteger)numberOfFlashModes;

- (BracketingSetting)bracketingSettingAtIndex:(NSInteger)index;
- (NSString*)bracketingSettingTitleAtIndex:(NSInteger)index;
- (NSInteger)numberOfBracketingSettings;

@end
