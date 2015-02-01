//
//  DrawerViewController.h
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/31/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DrawerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *drawerButton;
@property (weak, nonatomic) IBOutlet UIView *drawerContainerView;
@property (weak, nonatomic) IBOutlet UISlider *drawerSlider;

@property (nonatomic, copy) void(^sliderValueDidChange)(CGFloat);
@property (nonatomic, copy) void(^buttonTapped)(void);

@property (nonatomic) BOOL isOpen;

@end
