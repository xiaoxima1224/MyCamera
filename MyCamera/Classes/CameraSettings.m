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
    }
    return self;
}
@end
