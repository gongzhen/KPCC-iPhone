//
//  SCPRJogShuttleViewController.h
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, RewindDistance) {
    RewindDistanceBeginning = 0,
    RewindDistanceFifteen,
    RewindDistanceThirty,
    RewindDistanceOnboardingBeginning
};

typedef NS_ENUM(NSUInteger, SpinDirection) {
    SpinDirectionBackward = 0,
    SpinDirectionForward,
    SpinDirectionUnknown
};

@interface SCPRJogShuttleViewController : UIViewController

- (void)prepare;
- (void)animateWithSpeed:(CGFloat)duration
            hideableView:(UIView*)viewToHide
               direction:(SpinDirection)direction
               withSound:(BOOL)withSound
              completion:(void (^)(void))completion;

- (void)animateIndefinitelyWithViewToHide:(UIView*)hideableView completion:(void (^)(void))completion;

- (void)endAnimations;

@property BOOL spinning;
@property BOOL forceSingleRotation;

@end
