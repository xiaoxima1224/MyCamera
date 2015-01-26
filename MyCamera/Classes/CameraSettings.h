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
    kShutterTimerImmediate,
    kShutterTimerTwoSeconds,
    kShutterTImerTenSeconds
};

typedef NS_ENUM(NSInteger, BracketingSetting)
{
    kBracketingSettingNoBracketing,
    kBracketingSettingBurst,
    kBracketingSettingExposure,
    kBracketingSettingShutterSpeed,
};

@interface CameraSettings : NSObject

@property (nonatomic) AVCaptureFlashMode flashMode;

@property (nonatomic) ShutterTimerSetting timerSutting;

@property (nonatomic) BracketingSetting bracketingSetting;

@property (nonatomic) BOOL isAutoFocus;
@property (nonatomic) CGFloat lensPosition;


@end
