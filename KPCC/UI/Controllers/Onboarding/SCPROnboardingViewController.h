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

// Misc
@property (nonatomic,strong) IBOutlet UIView *orangeStripView;

// Branding
@property (nonatomic,strong) IBOutlet UIView *brandingView;
@property (nonatomic,strong) IBOutlet UIImageView *kpccLogoView;
@property (nonatomic,strong) IBOutlet UIView *dividerView;
@property (nonatomic,strong) IBOutlet UILabel *welcomeLabel;
@property (nonatomic,strong) IBOutlet UIButton *interactionButton;

// Lens
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *lensTopConstraint;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *lenstLeftConstraint;

// Notifications
@property (nonatomic,strong) IBOutlet UIView *notificationsView;
@property (nonatomic,strong) IBOutlet UIImageView *radioIconImage;
@property (nonatomic,strong) IBOutlet UILabel *notificationsCaptionLabel;
@property (nonatomic,strong) IBOutlet UILabel *notificationsQuestionLabel;
@property (nonatomic,strong) IBOutlet UIButton *yesToNotificationsButton;
@property (nonatomic,strong) IBOutlet UIButton *noToNotificationsButton;

- (void)prepare;
- (void)revealLensWithOrigin:(CGPoint)origin;
- (void)revealBrandingWithCompletion:(CompletionBlock)completed;
- (void)revealNotificationsPrompt;
- (void)collapseNotificationsPrompt;
- (void)hideLens;

// User responses
- (void)yesToNotifications;
- (void)noToNotifications;

@end
