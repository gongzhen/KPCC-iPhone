//
//  SCPRLensViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRAppDelegate.h"
#import "SimpleCompletionBlocks.h"

@interface SCPRLensViewController : UIViewController

@property (nonatomic,strong) CAShapeLayer *circleShape;
@property (nonatomic,strong) UIBezierPath *circlePath;
@property BOOL lock;

- (void)prepare;
- (void)squeezeWithAnchorView:(UIView*)anchorView completed:(CompletionBlock)completed;

@end
