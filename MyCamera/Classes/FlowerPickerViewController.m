//
//  FlowerPickerViewController.m
//  MyCamera
//
//  Created by Ma, Xiaoxi on 2/6/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "FlowerPickerViewController.h"
#import "UIView+Extension.h"


@interface FlowerPetalView ()

@property (nonatomic) CGAffineTransform bloomingTransform;
@property (nonatomic) CGPoint bloomingPosition;

@end


@interface FlowerPickerViewController ()

@property (nonatomic, strong) NSArray* petalViewsArr;
@property (nonatomic) CGFloat radius;

@end

@implementation FlowerPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.userInteractionEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Build the carpel
    _carpelView = [self.dataSource carpelViewForFlowerPicker:self];
    self.carpelView.frame = self.view.bounds;
    self.carpelView.layer.anchorPoint = CGPointMake(0.5, 0.5);
    self.carpelView.layer.position = CGPointMake(self.view.frameWidth/2, self.view.frameHeight/2);
    [self.view addSubview:self.carpelView];
    
    
    // Build the array of petals
    NSInteger numberOfPetals = [self.dataSource numberOfPetals:self];
    NSMutableArray* tempPetalViewsArr = [NSMutableArray arrayWithCapacity:numberOfPetals];
    for (int i = 0; i < numberOfPetals; i ++) {
        
        FlowerPetalView* petalView = [self.dataSource petalViewForFlowerPicker:self atIndex:i];
        [self.view addSubview:petalView];
        [self.view sendSubviewToBack:petalView];
        
        CGSize petalSize = [self.dataSource sizeOfPetalForFlowerPicker:self];
        petalView.frame = CGRectMake(0, 0, petalSize.width, petalSize.height);
        
        [tempPetalViewsArr addObject:petalView];
    }
    self.petalViewsArr = [tempPetalViewsArr copy];
    
    self.radius = [self calculateRadius];
    [self preparePetals];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)initWithFlowerPickerStyle:(FlowerPickerViewControllerStyle)style
{
    self = [super init];
    if (self) {
        self.style = style;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (FlowerPetalView* petalView in self.petalViewsArr)
    {
        [UIView animateWithDuration:0.35 animations:^{
            petalView.alpha = 1.0f;;
            petalView.layer.position = petalView.bloomingPosition;
        }];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:self.view];

    for (int i = 0; i < [self.petalViewsArr count]; i ++) {
        
        FlowerPetalView* petal = [self.petalViewsArr objectAtIndex:i];
        if (CGRectContainsPoint(petal.frame, touchLocation)) {
            
            if ([self.delegate respondsToSelector:@selector(flowerPicker:didSelectPetalAtIndex:)]) {
                [self.delegate flowerPicker:self didSelectPetalAtIndex:i];
            }
        }
    }
    
    [self retractPetals];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self retractPetals];
}

- (void)retractPetals
{
    CGPoint positionOffset = CGPointMake(self.carpelView.frameWidth/2, self.carpelView.frameHeight/2);
    [UIView animateWithDuration:0.2 animations:^{
        for (FlowerPetalView* petalView in self.petalViewsArr) {
            
            petalView.layer.position = CGPointMake(positionOffset.x, positionOffset.y);
            petalView.alpha = 0;
        }
    }];
}

- (CGFloat)calculateRadius
{
    if ([self.petalViewsArr count] == 0) return 0;
    
    CGFloat factor = 1;
    CGSize petalSize = ((UIView*)[self.petalViewsArr objectAtIndex:0]).frame.size;
    CGFloat distanceNeeded = [self.petalViewsArr count] * (petalSize.width * 1.5);
    
    switch (self.style) {
        case kFlowerPickerViewControllerStyleFullCircle:
            factor = 2;
            break;
            
        case kFlowerPickerViewControllerStyleHalfCircle:
            factor = 1;
            break;
        
        case kFlowerPickerViewControllerStyle120Degrees:
            factor = 2.0/3.0;
            break;
            
        default:
            break;
    }
    
    CGFloat circumference = M_PI * self.preferredPetalRadius * factor;
    
    if (distanceNeeded > circumference) {
        return distanceNeeded / (M_PI * factor);
    } else {
        return self.preferredPetalRadius;
    }
}

- (void)preparePetals
{
    if ([self.petalViewsArr count] == 0) return;
    
    CGFloat totalDegrees;
    CGFloat startingPoint = M_PI;
    
    switch (self.style) {
        case kFlowerPickerViewControllerStyleFullCircle:
            totalDegrees = 360;
            break;
            
        case kFlowerPickerViewControllerStyleHalfCircle:
            totalDegrees = 180;
            break;
            
        case kFlowerPickerViewControllerStyle120Degrees:
        {
            totalDegrees = 120;
            startingPoint = (210.0/180.0)*M_PI;
        }
            break;
        default:
            break;
    }
    
    NSInteger petalCount = [self.petalViewsArr count];
    CGFloat degreesPerPetal = (totalDegrees / petalCount)* M_PI / 180;
    CGPoint centerOffset = CGPointMake(self.carpelView.frameWidth/2, self.carpelView.frameHeight/2);
    
    for (int i = 0; i < petalCount; i ++) {
        
        FlowerPetalView* petal = [self.petalViewsArr objectAtIndex:i];
        petal.userInteractionEnabled = YES;
        petal.layer.anchorPoint = CGPointMake(0.5, 0.5);
        petal.alpha = 0;
        
        CGFloat degree = startingPoint + (i + 0.5f) * degreesPerPetal;
        CGPoint position = CGPointMake(self.radius * cosf(degree), -1 * self.radius * sinf(degree));
        position = CGPointMake(position.x + centerOffset.x, position.y + centerOffset.y);
        petal.bloomingPosition = position;
        
        
        // Only do transform for 120Degree style since it won't make sense for full circle and barely for half circle
        if (self.style == kFlowerPickerViewControllerStyle120Degrees) {
            
            CGAffineTransform transform = CGAffineTransformMakeRotation(atanf(cosf(degree) / sinf(degree)));
            petal.bloomingTransform = transform;
            petal.transform = transform;
        }
    }
    
}

#pragma mark - getters & setters

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    
    self.view.userInteractionEnabled = enabled;
    // TODO, draw a grey overlay
    self.view.backgroundColor = [UIColor lightGrayColor];
}

@end


@implementation FlowerCarpelView

- (id)init
{
    if (self = [super init]) {
        self.contentView = [[UIView alloc] initWithFrame:self.bounds];
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.contentView = [[UIView alloc] initWithFrame:self.bounds];
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
    }
    return self;
}

@end


@implementation FlowerPetalView

- (id)init
{
    if (self = [super init]) {
        self.contentView = [[UIView alloc] initWithFrame:self.bounds];
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.contentView = [[UIView alloc] initWithFrame:self.bounds];
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
    }
    return self;
}

@end