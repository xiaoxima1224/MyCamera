//
//  QuarterWheelViewController.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 2/4/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "QuarterWheelViewController.h"

@interface QuarterWheelViewController ()

@end

@implementation QuarterWheelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    UIView* circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, 120)];
    circle.layer.cornerRadius = 60;
    circle.backgroundColor = UIColorWithRGB(25, 180, 180);
    [self.view addSubview:circle];
    
//    UIView* circle2 = [[UIView alloc] initWithFrame:CGRectMake(40, 40, 80, 80)];
//    circle2.layer.cornerRadius = 40;
//    circle2.backgroundColor = [UIColor whiteColor];
//    [self.view addSubview:circle2];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
