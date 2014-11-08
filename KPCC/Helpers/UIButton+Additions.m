//
//  UIButton+Additions.m
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UIButton+Additions.h"
#import "Utils.h"

@implementation UIButton (Additions)

- (void)fadeImage:(UIImage*)image {
    [self fadeImage:image duration:0.15];
}

- (void)fadeImage:(UIImage *)image duration:(CGFloat)duration {
    [self setImage:image forState:UIControlStateNormal];
    [self setImage:image forState:UIControlStateHighlighted];
    
    CATransition *transition = [CATransition animation];
    transition.duration = duration;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    transition.type = kCATransitionFade;
    //transition.type = @";
    [self.layer addAnimation:transition
                      forKey:nil];
}

@end
