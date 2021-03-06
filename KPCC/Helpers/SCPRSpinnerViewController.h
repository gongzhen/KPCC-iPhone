//
//  SCPRSpinnerViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 10/29/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Utils.h"

@interface SCPRSpinnerViewController : UIViewController

+ (SCPRSpinnerViewController*)o;
+ (void)spinInCenterOfViewController:(UIViewController*)viewController appeared:(Block)appeared;
+ (void)spinInCenterOfView:(UIView *)view appeared:(Block)appeared;
+ (void)spinInCenterOfView:(UIView *)view offset:(CGFloat)yOffset appeared:(Block)appeared;
+ (void)spinInCenterOfView:(UIView *)view offset:(CGFloat)yOffset delay:(CGFloat)delay appeared:(Block)appeared;
+ (void)finishSpinning;
- (void)spin;

@end
