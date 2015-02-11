//
//  UIView+Extension.m
//  TestFlowerPicker
//
//  Created by Ma, Xiaoxi on 2/7/15.
//  Copyright (c) 2015 Ma, Xiaoxi. All rights reserved.
//

#import "UIView+Extension.h"

@implementation UIView (Extension)

- (void)setLeft:(CGFloat)left
{
    self.frame = CGRectMake(left, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
}

- (CGFloat)left
{
    return self.frame.origin.x;
}

- (void)setRight:(CGFloat)right
{
    self.frame = CGRectMake(right-self.frame.size.width, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
}

- (CGFloat)right
{
    return self.frame.origin.x + self.frame.size.width;
}

- (void)setTop:(CGFloat)top
{
    self.frame = CGRectMake(self.frame.origin.x, top, self.frame.size.width, self.frame.size.height);
}

- (CGFloat)top
{
    return self.frame.origin.y;
}

- (void)setBottom:(CGFloat)bottom
{
    self.frame = CGRectMake(self.frame.origin.x, bottom-self.frame.size.height, self.frame.size.width, self.frame.size.height);
}

- (CGFloat)bottom
{
    return self.frame.origin.y + self.frame.size.height;
}

- (void)setFrameWidth:(CGFloat)frameWidth
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, frameWidth, self.frame.size.height);
}

- (CGFloat)frameWidth
{
    return self.frame.size.width;
}

- (void)setFrameHeight:(CGFloat)frameHeight
{
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, frameHeight);
}

- (CGFloat)frameHeight
{
    return self.frame.size.height;
}

@end
