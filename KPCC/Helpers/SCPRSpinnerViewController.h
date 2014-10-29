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
+ (void)spinInCenterOfViewController:(UIViewController*)viewController appeared:(CompletionBlock)appeared;
+ (void)finishSpinning;
- (void)spin;

@end
