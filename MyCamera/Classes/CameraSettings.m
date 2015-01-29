//
//  CameraSettings.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/26/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "CameraSettings.h"

@implementation CameraSettings

- (id)init
{
    self = [super init];
    if (self) {
        self.flashMode = AVCaptureFlashModeAuto;
        self.timerSetting = kShutterTimerImmediate;
        self.bracketingSetting = kBracketingSettingNoBracketing;
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
@end
