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
#import "SCPRTextCalloutViewController.h"

@interface SCPROnboardingViewController : UIViewController


@property (nonatomic,strong) IBOutlet SCPRLensViewController *lensVC;

// Misc
@property (nonatomic,strong) IBOutlet UIView *orangeStripView;
@property (nonatomic,strong) UIView *navbarMask;

// Branding
@property (nonatomic,strong) IBOutlet UIView *brandingView;
@property (nonatomic,strong) IBOutlet UIImageView *kpccLogoView;
@property (nonatomic,strong) IBOutlet UIView *dividerView;
@property (nonatomic,strong) IBOutlet UILabel *welcomeLabel;
@property (nonatomic,strong) IBOutlet UIButton *interactionButton;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *logoTopAnchor;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *sloganTopAnchor;
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
@property (nonatomic,strong) IBOutlet SCPRTextCalloutViewController *textCalloutBalloonCtrl;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *calloutAnchor;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *buttonAnchor;

// Ondemand
@property (nonatomic,strong) IBOutlet UIImageView *onDemandSwipeImageView;
@property (nonatomic,strong) IBOutlet UILabel *swipeToSkipLabel;
@property (nonatomic,strong) IBOutlet UIButton *gotItButton;
@property (nonatomic,strong) IBOutlet UIView *onDemandContainerView;

- (void)prepare;
- (void)revealLensWithOrigin:(CGPoint)origin;
- (void)revealBrandingWithCompletion:(CompletionBlock)completed;
- (void)revealNotificationsPrompt;
- (void)collapseNotificationsPrompt;
- (void)hideLens;
- (void)showCalloutWithText:(NSString*)text pointerPosition:(CGFloat)pointer position:(CGPoint)position;
- (void)hideCallout;
- (void)ondemandMode;

// User responses
- (void)yesToNotifications;
- (void)noToNotifications;

@end
