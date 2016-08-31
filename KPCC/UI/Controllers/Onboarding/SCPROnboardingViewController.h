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
#import "SCPRButton.h"
#import "BlockTypes.h"

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
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *dividerWidthAnchor;

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
@property (nonatomic,strong) IBOutlet SCPRButton *gotItButton;
@property (nonatomic,strong) IBOutlet UIView *onDemandContainerView;
@property (nonatomic,strong) UISwipeGestureRecognizer *swiper;

// Scrubbing
@property (nonatomic,strong) IBOutlet UIImageView *scrubbingSwipeImageView;
@property (nonatomic,strong) IBOutlet UILabel *scrubbingSwipeToSkipLabel;
@property (nonatomic,strong) IBOutlet SCPRButton *scrubbingGotItButton;
@property (nonatomic,strong) IBOutlet UIView *scrubbingContainerView;
@property (nonatomic,strong) UISwipeGestureRecognizer *scrubbingSwiper;
@property (nonatomic,strong) IBOutlet UIView *fakeScrubberView;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *topAnchorScrubbingConstraint;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *topAnchorForFingerAndBar;

@property BOOL dontFade;

// Backdoor
@property (nonatomic,strong) UISwipeGestureRecognizer *backdoorSkipSwiper;

- (void)prepare;
- (void)revealLensWithOrigin:(CGPoint)origin;
- (void)revealBrandingWithCompletion:(Block)completed;
- (void)revealNotificationsPrompt;
- (void)collapseNotificationsPrompt;
- (void)hideLens;
- (void)showCalloutWithText:(NSString*)text pointerPosition:(CGFloat)pointer position:(CGPoint)position;
- (void)hideCallout;
- (void)onboardingSwipingAction:(BOOL)schedule;
- (void)onboardingScrubbingAction;
- (void)onboardingScrubbingAction:(BOOL)live;

- (void)dismissOnDemand;
- (void)dismissSchedule;

// User responses
- (void)yesToNotifications;
- (void)noToNotifications;

@end
