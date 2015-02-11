//
//  FlowerPickerViewController.h
//  MyCamera
//
//  Created by Ma, Xiaoxi on 2/6/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FlowerPickerViewController;
@class FlowerCarpelView;
@class FlowerPetalView;

@protocol FlowerPickerViewControllerDelegate <NSObject>

@required
- (void)flowerPicker:(FlowerPickerViewController*)flowerPicker didSelectPetalAtIndex:(NSInteger)index;

@end


@protocol FlowerPickerViewControllerDataSource <NSObject>

@required
- (NSInteger)numberOfPetals:(FlowerPickerViewController*)flowerPicker;
- (FlowerCarpelView*)carpelViewForFlowerPicker:(FlowerPickerViewController*)flowerPicker;
- (FlowerPetalView*)petalViewForFlowerPicker:(FlowerPickerViewController*)flowerPicker atIndex:(NSInteger)index;
- (CGSize)sizeOfPetalForFlowerPicker:(FlowerPickerViewController*)flowerPicker;

@end


@interface FlowerCarpelView : UIView

@property (nonatomic, strong) UIView* contentView;

@end


@interface FlowerPetalView : UIView

@property (nonatomic, strong) UIView* contentView;

@end



/* Petals start from the 9-o'clock position and goes counter clockwise for full and half circle, 
   120Degrees start from 8 o'clock, go counter-clock wise to 4 o'clock */

typedef NS_ENUM(NSInteger, FlowerPickerViewControllerStyle)
{
    kFlowerPickerViewControllerStyleFullCircle,
    kFlowerPickerViewControllerStyleHalfCircle,
    kFlowerPickerViewControllerStyle120Degrees
};

@interface FlowerPickerViewController : UIViewController

@property (nonatomic) BOOL enabled;

@property (nonatomic, weak) id<FlowerPickerViewControllerDelegate> delegate;
@property (nonatomic, weak) id<FlowerPickerViewControllerDataSource> dataSource;

@property (nonatomic) FlowerPickerViewControllerStyle style;
@property (nonatomic) CGFloat preferredPetalRadius;

@property (nonatomic, strong,readonly) FlowerCarpelView* carpelView;

- (id)initWithFlowerPickerStyle:(FlowerPickerViewControllerStyle)style;

@end
