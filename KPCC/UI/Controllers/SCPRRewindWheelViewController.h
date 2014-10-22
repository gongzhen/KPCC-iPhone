//
//  SCPRRewindWheelViewController.h
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, RewindDistance) {
    RewindDistanceBeginning = 0,
    RewindDistanceFifteen,
    RewindDistanceThirty
};

@interface SCPRRewindWheelViewController : UIViewController

- (void)prepare;
- (void)animateWithSpeed:(CGFloat)duration
                 tension:(CGFloat)tension
                   color:(UIColor*)color
             strokeWidth:(CGFloat)strokeWidth
            hideableView:(UIView*)viewToHide
              completion:(void (^)(void))completion;
- (void)endAnimations;

@end
