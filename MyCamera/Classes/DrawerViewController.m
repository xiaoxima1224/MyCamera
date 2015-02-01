//
//  DrawerViewController.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 1/31/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "DrawerViewController.h"

@interface DrawerViewController ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *buttonSizeRatioConstraint;

@end

@implementation DrawerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.drawerSlider addTarget:self action:@selector(sliderValueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadView
{
    self.view = [[[NSBundle mainBundle] loadNibNamed:@"DrawerViewController" owner:self options:nil] firstObject];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    if (parent) {
        [self rotateSubviewsForSize:self.view.frame.size];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [self rotateSubviewsForSize:size];
}

- (void)rotateSubviewsForSize:(CGSize)size
{
    self.drawerButton.transform = CGAffineTransformRotate(self.view.transform, M_PI);
    
    CGFloat multiplier = 1;
    if (size.width > size.height) { // Landscape
        multiplier = 3/4;
    }
    else { // Portrait
        multiplier = 4/3;
    }
    
    [self.drawerButton removeConstraint:self.buttonSizeRatioConstraint];
    self.buttonSizeRatioConstraint = [NSLayoutConstraint constraintWithItem:self.drawerButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.drawerButton attribute:NSLayoutAttributeHeight multiplier:multiplier constant:0];
    [self.drawerButton addConstraint:self.buttonSizeRatioConstraint];
    
    [self.view setNeedsUpdateConstraints];
    [self.view updateConstraintsIfNeeded];
}

- (IBAction)buttonTapped:(id)sender
{
    if (self.buttonTapped) {
        self.buttonTapped();
    }
}

- (void)sliderValueChanged
{
    if (self.sliderValueDidChange) {
        self.sliderValueDidChange(self.drawerSlider.value);
    }
}
@end
