//
//  SCPRKeyboardToolbar.m
//  KPCC
//
//  Created by Ben Hochberg on 12/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRKeyboardToolbar.h"
#import "SCPRAppDelegate.h"
#import "Utils.h"

@implementation SCPRKeyboardToolbar

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)prep {
    UIWindow *mw = [[Utils del] window];
    [self.topMargin setConstant:mw.frame.size.height];
    [self.superview layoutIfNeeded];
}

- (void)presentOnController:(UIViewController *)controller withOptions:(NSDictionary *)options {

    
    //[controller.view addSubview:self];
    
    
    /*
    UIWindow *mw = [[Utils del] window];
    NSLayoutConstraint *lead = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeLeading
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:controller.view
                                                         attribute:NSLayoutAttributeLeading
                                                        multiplier:1
                                                          constant:0.0f];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:controller.view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1
                                                            constant:mw.frame.size.height];
    
    NSLayoutConstraint *train = [NSLayoutConstraint constraintWithItem:self
                                                             attribute:NSLayoutAttributeTrailing
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:controller.view
                                                             attribute:NSLayoutAttributeTrailing
                                                            multiplier:1
                                                              constant:0.0f];
    
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1
                                                               constant:44.0];*/
    
    //[controller.view addConstraints:@[ lead, top, train ]];
    //[self addConstraint:height];
    
    //self.topMargin = top;
    CGFloat constant = [Utils isIOS8] ? 64.0 : 225.0f;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.33 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.topMargin setConstant:constant];
            self.alpha = 1.0f;
            [controller.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            
        }];
    });
}

- (void)dismiss {
    
    UIWindow *mw = [[Utils del] window];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.33 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.topMargin setConstant:mw.frame.size.height];
            [self.superview layoutIfNeeded];
        } completion:^(BOOL finished) {
         
        }];
    });
    
}

@end
