//
//  FlowerPickerViewController.h
//  MyCamera
//
//  Created by Ma, Xiaoxi on 2/6/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FlowerPickerViewController;
@protocol FlowerPickerViewControllerDelegate <NSObject>

@required
- (void)flowerPicker:(FlowerPickerViewController*)flowerPicker didSelectPetalAtIndex:(NSInteger)index;

@end


@protocol FlowerPickerViewControllerDataSource <NSObject>

@required
- (NSInteger)numberOfPetals:(FlowerPickerViewController*)flowerPicker;
- (UIView*)carpelViewForFlowerPicker:(FlowerPickerViewController*)flowerPicker;
- (UIView*)petalViewForFlowerPicker:(FlowerPickerViewController*)flowerPicker atIndex:(NSInteger)index;

@optional
- (CGSize)sizeOfCarpelViewForFlowerPicker:(FlowerPickerViewController*)flowerPicker;
- (CGSize)sizeOfPetalForFlowerPicker:(FlowerPickerViewController*)flowerPicker;

@end


typedef NS_ENUM(NSInteger, FlowerPickerViewControllerStyle)
{
    kFlowerPickerViewControllerStyleFullCircle,
    kFlowerPickerViewControllerStyleHalfCircle
};

@interface FlowerPickerViewController : UIViewController

@property (nonatomic, weak) id<FlowerPickerViewControllerDelegate> delegate;
@property (nonatomic, weak) id<FlowerPickerViewControllerDataSource> dataSource;

@property (nonatomic) FlowerPickerViewControllerStyle style;
@property (nonatomic) CGFloat preferredPetalRadius;

@property (nonatomic, strong) UIView* carpelView;

- (id)initWithFlowerPickerStyle:(FlowerPickerViewControllerStyle)style;

@end
