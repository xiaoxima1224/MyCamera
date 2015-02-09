//
//  FlowerPickerViewController.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 2/6/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "FlowerPickerViewController.h"

@interface FlowerPickerViewController ()

@end

@implementation FlowerPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)initWithFlowerPickerStyle:(FlowerPickerViewControllerStyle)style
{
    self = [self init];
    self.style = style;
    
    return self;
}

@end
