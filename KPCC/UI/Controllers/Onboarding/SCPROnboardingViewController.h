//
//  SCPROnboardingViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRLensViewController.h"
#import "SCPRTextCalloutViewController.h"
#import <POP/POP.h>
#import "SCPRAppDelegate.h"


@interface SCPROnboardingViewController : UIViewController


@property (nonatomic,strong) IBOutlet SCPRLensViewController *lensVC;

// Branding
@property (nonatomic,strong) IBOutlet UIView *brandingView;
@property (nonatomic,strong) IBOutlet UIImageView *kpccLogoView;
@property (nonatomic,strong) IBOutlet UIView *dividerView;
@property (nonatomic,strong) IBOutlet UILabel *welcomeLabel;
@property (nonatomic,strong) IBOutlet UIButton *interactionButton;

// Lens
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *lensTopConstraint;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *lenstLeftConstraint;

- (void)prepare;
- (void)revealLensWithOrigin:(CGPoint)origin;
- (void)revealBrandingWithCompletion:(CompletionBlock)completed;

@end
