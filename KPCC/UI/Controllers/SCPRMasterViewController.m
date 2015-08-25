//
//  SCPRMasterViewController.m
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMasterViewController.h"
#import "SCPRMenuButton.h"
#import "SCPRProgramsListViewController.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import "SCPRSlideInTransition.h"
#import "SCPRShortListViewController.h"
#import "SCPRQueueScrollableView.h"
#import "NSDate+Helper.h"
#import "SessionManager.h"
#import "SCPRCloakViewController.h"
#import "SCPRFeedbackViewController.h"
#import "UXmanager.h"
#import "SCPRNavigationController.h"
#import "AnalyticsManager.h"
#import "SCPROnboardingViewController.h"
#import "UIView+PrintDimensions.h"
#import "SCPRScrubbingUIViewController.h"
#import "SCPRTimerControlViewController.h"
#import "SCPRPledgePINViewController.h"
#import "SCPRBalloonViewController.h"
#import "Utils.h"
#import "SCPRLoginViewController.h"
#import "SCPRProfileViewController.h"

@import MessageUI;

static NSString *kRewindingText = @"REWINDING...";
static NSString *kForwardingText = @"GOING LIVE...";
static NSString *kBufferingText = @"BUFFERING";
static CGFloat kScrubbingThreeFiveSlip = 16.0f;
static NSInteger kCancelSleepTimerAlertTag = 44839;

@interface SCPRMasterViewController () <AudioManagerDelegate, UINavigationControllerDelegate, UIViewControllerTransitioningDelegate, SCPRPreRollControllerDelegate, UIScrollViewDelegate>

@property BOOL initialPlay;
@property BOOL setPlaying;
@property BOOL seekRequested;
@property BOOL busyZoomAnim;
@property BOOL jogging;
@property BOOL setForLiveStreamUI;
@property BOOL setForOnDemandUI;
@property BOOL dirtyFromRewind;
@property BOOL queueBlurShown;
@property BOOL queueLoading;

@property IBOutlet NSLayoutConstraint *playerControlsTopYConstraint;
@property IBOutlet NSLayoutConstraint *playerControlsBottomYConstraint;
@property IBOutlet NSLayoutConstraint *rewindWidthConstraint;
@property IBOutlet NSLayoutConstraint *rewindHeightContraint;
@property IBOutlet NSLayoutConstraint *programTitleYConstraint;

- (void)playAudio:(BOOL)hard;
- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk;
- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk completion:(CompletionBlock)completion;
- (void)lockUI:(id)note;
- (void)unlockUI:(id)note;
- (void)finishUpdatingForProgram;

@end

@implementation SCPRMasterViewController

@synthesize pulldownMenu,
seekRequested,
initialPlay,
setPlaying,
busyZoomAnim,
setForLiveStreamUI,
setForOnDemandUI;

#pragma mark - External Control

// Allows for interaction with system audio controls.

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlPlayOrPause {
    if ( [[AudioManager shared] currentAudioMode] == AudioModePreroll ) {
        if ( [self.preRollViewController.prerollPlayer rate] > 0.0 ) {
            [self.preRollViewController.prerollPlayer pause];
        } else {
            [self.preRollViewController.prerollPlayer play];
        }
        return;
    }
    
    if ( self.initialPlay ) {
        [self playOrPauseTapped:nil];
    } else {
        [self initialPlayTapped:nil];
    }
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    NSLog(@" >>>>>> EVENT RECEIVED FROM OTHER REMOTE CONTROL SOURCE <<<<<< ");
    NSString *pretty = @"";
    NSString *ammendment = @"";
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self remoteControlPlayOrPause];
            pretty = @"Toggle Play / Pause";
        } else if ( event.subtype == UIEventSubtypeRemoteControlPause ) {
            if ( [[AudioManager shared] isPlayingAudio] ) {
                [self remoteControlPlayOrPause];
            } else {
                ammendment = @", but we're going to ignore it";
            }
            pretty = @"Hard Pause";
        } else if ( event.subtype == UIEventSubtypeRemoteControlPlay ) {
            if ( ![[AudioManager shared] isPlayingAudio] ) {
                [self remoteControlPlayOrPause];
            } else {
                ammendment = @", but we're going to ignore it";
            }
            pretty = @"Hard Play";
        }
    }
    NSLog(@"Received : %@%@",pretty,ammendment);
}

- (void)handleResponseForNotification {
    
    NSLog(@" >>>>>>> PROCESSING NOTIFICATION ON LAUNCH <<<<<<< ");
    
    [[Utils del] setUserRespondedToPushWhileClosed:NO];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    if ( self.menuOpen ) {
        [self decloakForMenu:YES];
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        if ( [[AudioManager shared] isPlayingAudio] ) {
            [[AudioManager shared] adjustAudioWithValue:-1.0 completion:^{
                NSLog(@"Going live from an ondemand session");
                [self goLive:YES];
            }];
            return;
        } else {
            [self goLive:YES];
            return;
        }
    } else if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        if ( [[AudioManager shared] status] == StreamStatusPaused ) {
            [[AudioManager shared] resetPlayer];
        } else if ( [[SessionManager shared] sessionIsBehindLive] ) {
            [[SessionManager shared] setLastKnownPauseExplanation:PauseExplanationAppIsRespondingToPush];
            [[AudioManager shared] pauseAudio];
            [[AudioManager shared] resetPlayer];
        } else if ( [[AudioManager shared] isPlayingAudio] ) {
            // OK to do nothing here
            return;
        }
    }
    
    if ( self.preRollViewController.tritonAd ) {
        self.preRollViewController.tritonAd = nil;
    }
    
    if ( self.initialPlay ) {
        [self playOrPauseTapped:nil];
    } else {
        [self initialPlayTapped:nil];
    }
    
}

#pragma mark - Standard View Callbacks

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[AnalyticsManager shared] screen:@"liveStreamView"];
    
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    self.hiddenVector = [NSMutableArray new];
    
    
    self.view.backgroundColor = [UIColor blackColor];
    self.horizDividerLine.layer.opacity = 0.0f;
    self.queueBlurView.layer.opacity = 0.0f;
    self.scrubbingUIView.alpha = 0.0f;
    self.shareButton.alpha = 0.0f;
    
    self.darkBgView.hidden = NO;
    self.darkBgView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.7];
    self.darkBgView.layer.opacity = 0.0f;
    self.queueBlurView.alpha = 1.0f;
    self.darkBgView.alpha = 1.0f;
    self.onDemandMainDividerView.alpha = 0.4f;

    self.deployedProgramTitleConstant = [Utils isThreePointFive] ? 143.0f : 220.0f;
    self.initialProgramTitleConstant = [Utils isThreePointFive] ? 56.0f : 118.0f;
    
    self.threePointFivePlayControlsConstant = 10.0f;
    
    if ( [Utils isThreePointFive] ) {
        if ( [Utils isIOS8] ) {
            [self.initialControlsYConstraint setConstant:151.0];
            [self.playerControlsTopYConstraint setConstant:288.0];
            if ( [[UXmanager shared].settings userHasViewedOnboarding] ) {
                self.initialProgramTitleConstant = 148.0f;
            } else {
                self.initialProgramTitleConstant = 200.0f;
            }
            self.deployedProgramTitleConstant = 220.0f;
            [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
        } else {
            [self.initialControlsYConstraint setConstant:151.0];
            [self.playerControlsTopYConstraint setConstant:258.0];
            self.liveRewindBottomYConstraint.constant = 10.0f;
            [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
            self.deployedProgramTitleConstant = 113.0f;
        }
    } else {
        [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
    }
    
    [[Utils del] applyXFSButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockUI:)
                                                 name:@"network-status-fail"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tickSleepTimer)
                                                 name:@"sleep-timer-ticked"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showSleepTimer)
                                                 name:@"sleep-timer-armed"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideSleepTimer)
                                                 name:@"sleep-timer-disarmed"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideSleepTimer)
                                                 name:@"sleep-timer-fired"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsHidden)
                                                 name:@"xfs-hidden"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsShown)
                                                 name:@"xfs-shown"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsToggle)
                                                 name:@"xfs-toggle"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsConfirm)
                                                 name:@"xfs-confirmation-entry"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsExit)
                                                 name:@"xfs-confirmation-exit"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(composeMail:)
                                                 name:@"compose-mail"
                                               object:nil];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    self.liveProgressViewController = [[SCPRProgressViewController alloc] init];
    self.liveProgressViewController.view = self.liveProgressView;
    self.liveProgressViewController.liveProgressView = self.liveProgressBarView;
    self.liveProgressViewController.currentProgressView = self.currentProgressBarView;
    self.playerControlsView.backgroundColor = [UIColor clearColor];
    self.progressView.alpha = 0.0f;
    self.liveProgressView.alpha = 0.0f;
    
    self.queueBlurView.contentMode = UIViewContentModeScaleAspectFill;
    
    self.liveRewindAltButton.userInteractionEnabled = NO;
    [self.liveRewindAltButton setAlpha:0.0f];
    
    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    pulldownMenu.delegate = self;
    [self.view addSubview:pulldownMenu];
    [pulldownMenu loadMenu];
    [pulldownMenu primeWithType:MenuTypeStandard];
    
    self.pulldownMenu.alpha = 0.0f;
    
    // Set up pre-roll child view controller.
    [self addPreRollController];
    
    // Fetch program info and update audio control state.
    //[self updateDataForUI];
    
    // Observe when the application becomes active again, and update UI if need-be.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(primeManualControlButton)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    
    // Make sure the system follows our playback status - to support the playback when the app enters the background mode.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    
    // Config blur view.
    [self.blurView setAlpha:0.0];
    [self.blurView setTintColor:[UIColor clearColor]];
    [self.blurView setBlurRadius:20.0f];
    [self.blurView setDynamic:NO];
    
    // Config dark background view. Will sit on top of blur view, between player controls view.
    [self.darkBgView.layer setOpacity:0.0];
    
    // Initially flag as KPCC Live view
    setForLiveStreamUI = YES;
    [self primeRemoteCommandCenter:YES];
    
    self.jogShuttle = [[SCPRJogShuttleViewController alloc] init];
    self.jogShuttle.view = self.rewindView;
    self.jogShuttle.view.alpha = 0.0f;
    [self.jogShuttle prepare];
    
    // Views for audio queue
    self.queueScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64,
                                                                          self.view.frame.size.width,
                                                                          self.timeLabelOnDemand.frame.origin.y - 64)];
    self.queueScrollView.backgroundColor = [UIColor clearColor];
    self.queueScrollView.pagingEnabled = YES;
    self.queueScrollView.delegate = self;
    self.queueScrollView.hidden = YES;
    [self.view insertSubview:self.queueScrollView belowSubview:self.initialControlsView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(treatUIforProgram)
                                                 name:@"program-has-changed"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xfsAvailability)
                                                 name:@"pledge-drive-status-updated"
                                               object:nil];
    
    [self.queueBlurView setAlpha:0.0];
    [self.queueBlurView setTintColor:[UIColor clearColor]];
    [self.queueDarkBgView setAlpha:0.0];
    
    self.view.alpha = 0.0f;
    [self.letsGoLabel proMediumFontize];
    self.letsGoLabel.alpha = 0.0f;
    
    [self adjustScrubbingState];
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] loadOnboarding];
    } else {
        [[UXmanager shared] quietlyAskForNotificationPermissions];
    }
    
    [self.initialPlayButton addTarget:self
                               action:@selector(initialPlayTapped:)
                     forControlEvents:UIControlEventTouchUpInside
                              special:YES];
    
    [self.playPauseButton addTarget:self
                             action:@selector(playOrPauseTapped:)
                   forControlEvents:UIControlEventTouchUpInside
                            special:YES];
    
    if ( [Utils isIOS8] ) {
        [self.shareButton addTarget:self
                             action:@selector(shareButtonTapped:)
                   forControlEvents:UIControlEventTouchUpInside
                            special:YES];
    } else {
        [self.shareButton addTarget:self
                             action:@selector(shareButtonTapped:)
                   forControlEvents:UIControlEventTouchUpInside];
    }
    
    [self.cancelSleepTimerButton addTarget:self
                                    action:@selector(cancelSleepTimerAction)
                          forControlEvents:UIControlEventTouchUpInside];
    
    [self.mainBackward30Button addTarget:self
                                  action:@selector(seekBack30)
                        forControlEvents:UIControlEventTouchUpInside
                                 special:YES];
    
    [self.mainForward30Button addTarget:self
                                 action:@selector(seekFwd30)
                       forControlEvents:UIControlEventTouchUpInside
                                special:YES];
    
    [self setupTimerControls];
    
    self.previousRewindThreshold = 0;
    self.mpvv = [[MPVolumeView alloc] initWithFrame:CGRectMake(-30.0, -300.0, 1.0, 1.0)];
    self.mpvv.alpha = 0.1;
    [self.view addSubview:self.mpvv];
    
    NSLog(@"Program Title Y Lock : %1.1f",self.programTitleYConstraint.constant);
    

    [[AudioManager shared] loadXfsStreamUrlWithCompletion:^{
        [[NetworkManager shared] setupReachability];
    }];

    
    self.originalFrames = [NSMutableDictionary new];
    self.navigationItem.title = kMainLiveStreamTitle;
    
    [self primeScrubber];
    [self setupScroller];
    
    
    [SCPRCloakViewController cloakWithCustomCenteredView:nil cloakAppeared:^{
        if ( [[UXmanager shared] userHasSeenOnboarding] ) {
            
            [self updateDataForUI];
            [self.view layoutIfNeeded];
            [self.liveStreamView layoutIfNeeded];
            
            [self.blurView setNeedsDisplay];
            
            [self.mainContentScroller printDimensionsWithIdentifier:@"Main Scroller"];
            [self.liveStreamView printDimensionsWithIdentifier:@"Live Stream View"];
            
            self.originalFrames[@"playerControls"] = @(self.playerControlsBottomYConstraint.constant);
            self.originalFrames[@"programTitle"] = @(self.programTitleYConstraint.constant);
            self.originalFrames[@"liveRewind"] = @(self.liveRewindBottomYConstraint.constant);
        
        }
    }];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[DesignManager shared] treatBar];
    [AudioManager shared].delegate = self;
    
    if (self.menuOpen) {
        self.navigationItem.title = @"Menu";
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.queueBlurView setNeedsDisplay];
    
    if ( [[NetworkManager shared] networkDown] ) {
        self.initialPlayButton.userInteractionEnabled = NO;
        self.initialPlayButton.alpha = 0.4f;
    }
    
    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[UXmanager shared] beginOnboarding:self];
            
        });
    }
    
    if ( self.restoreTitle ) {
        self.restoreTitle = NO;
        self.homeIsNotRootViewController = NO;
        self.navigationItem.title = kMainLiveStreamTitle;
    }
    
    self.viewHasAppeared = YES;

}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewDidLayoutSubviews {


    [self.upcomingScreen alignDividerToValue:self.horizDividerLine.frame.origin.y];
    
    
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    /*if ( SEQ(self.navigationItem.title,kMainLiveStreamTitle) ) {
        //[[Utils del] controlXFSAvailability:[[SessionManager shared] xFreeStreamIsAvailable]];
    } else {
        [[Utils del] controlXFSAvailability:NO];
    }*/
}

- (void)superPop {
    
    /*if ( self.menuOpen ) {
        [self decloakForMenu:YES];
    }
    */
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    self.navigationItem.title = kMainLiveStreamTitle;
}

- (void)setupScroller7 {
    self.mainContentScroller.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainContentScroller.pagingEnabled = YES;
    self.upcomingScreen = [[SCPRUpcomingProgramViewController alloc] initWithNibName:@"SCPRUpcomingProgramViewController"
                                                                              bundle:nil];
    self.cpFullDetailScreen = [[SCPRCompleteScheduleViewController alloc] initWithNibName:@"SCPRCompleteScheduleViewController"
                                                                                   bundle:nil];
    
    
    self.upcomingScreen.view.frame = self.upcomingScreen.view.frame;
    self.cpFullDetailScreen.view.frame = self.cpFullDetailScreen.view.frame;
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                   self.mainContentScroller.frame.size.width*3.0,
                                                                   self.view.frame.size.height-64.0)];
    [self.mainContentScroller addSubview:contentView];
}

- (void)setupScroller {
    
    self.mainContentScroller.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainContentScroller.pagingEnabled = YES;
    
    NSString *xib = [Utils isIOS8] ? @"SCPRUpcomingProgramViewController" : @"SCPRUpcomingProgramViewController7";
    self.upcomingScreen = [[SCPRUpcomingProgramViewController alloc] initWithNibName:xib
                                                                       bundle:nil];
    self.cpFullDetailScreen = [[SCPRCompleteScheduleViewController alloc] initWithNibName:@"SCPRCompleteScheduleViewController"
                                                                                   bundle:nil];
    

    self.upcomingScreen.view.frame = self.upcomingScreen.view.frame;
    self.cpFullDetailScreen.view.frame = self.cpFullDetailScreen.view.frame;
    

    CGFloat push = 0.0f;
    CGFloat heightHint = [Utils isThreePointFive] ? self.view.frame.size.height-64.0f : self.liveStreamView.frame.size.height;
    if ( [Utils isThreePointFive] ) {
        push = 88.0f;
    }
    
#ifdef DEBUG
    //self.liveStreamView.backgroundColor = [[UIColor kpccPeriwinkleColor] translucify:0.75f];
    //self.upcomingScreen.view.backgroundColor = [[UIColor kpccOrangeColor] translucify:0.75f];
    //self.cpFullDetailScreen.view.backgroundColor = [[UIColor kpccSlateColor] translucify:0.75f];
#endif

    UIView *v2u = [Utils isIOS8] ? self.mainContentScroller : self.liveStreamView;
    //[v2u printDimensionsWithIdentifier:@">>>>>>>>>>>>>>>>>>>>>>>>>> Basis for scroll content"];
    
    NSArray *cpSizeConstraints = [[[DesignManager shared] sizeConstraintsForView:self.upcomingScreen.view hints:@{ @"height" : @(heightHint),
                                                                                                            @"width" : @(v2u.frame.size.width)}] allValues];
    
    NSArray *fsSizeConstraints = [[[DesignManager shared] sizeConstraintsForView:self.cpFullDetailScreen.view hints:@{ @"height" : @(heightHint),
                                                                                                            @"width" : @(v2u.frame.size.width)}] allValues];
    self.upcomingScreen.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.cpFullDetailScreen.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveStreamView.translatesAutoresizingMaskIntoConstraints = NO;
    

    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                   self.mainContentScroller.frame.size.width*3.0,
                                                                   self.view.frame.size.height)];
    contentView.backgroundColor = [UIColor clearColor];
    UIView *cv2u = [Utils isIOS8] ? self.mainContentScroller : contentView;
    if ( ![Utils isIOS8] ) {
        [self.liveStreamView removeFromSuperview];
        [contentView addSubview:self.liveStreamView];
        NSArray *lsSizeConstraints = [[[DesignManager shared] sizeConstraintsForView:self.liveStreamView hints:@{ @"height" : @(heightHint),
                                                                                                                           @"width" : @(v2u.frame.size.width)}] allValues];
        [self.liveStreamView addConstraints:lsSizeConstraints];
        [self.mainContentScroller addSubview:contentView];
        
        NSString *usVfmt = [NSString stringWithFormat:@"V:|-%1.1f-[live]",push];
        NSArray *fVConstraints = [NSLayoutConstraint constraintsWithVisualFormat:usVfmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:@{ @"live" : self.liveStreamView }];
        [contentView addConstraints:fVConstraints];
        
    }
    [cv2u addSubview:self.upcomingScreen.view];
    [cv2u addSubview:self.cpFullDetailScreen.view];
   
    [self.upcomingScreen.view addConstraints:cpSizeConstraints];
    [self.cpFullDetailScreen.view addConstraints:fsSizeConstraints];
    
    
    NSString *fmt = [Utils isIOS8] ? @"H:|[mainView][upcomingScreen][cpFull]" : @"H:|[mainView][upcomingScreen][cpFull]";
    NSArray *fConstraints = [NSLayoutConstraint constraintsWithVisualFormat:fmt
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"mainView" : self.liveStreamView,
                                                                               @"upcomingScreen" : self.upcomingScreen.view,
                                                                               @"cpFull" : self.cpFullDetailScreen.view }];
    
    NSString *usVfmt = [NSString stringWithFormat:@"V:|-%1.1f-[upcomingScreen]",push];
    NSArray *fVConstraints = [NSLayoutConstraint constraintsWithVisualFormat:usVfmt
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"upcomingScreen" : self.upcomingScreen.view }];
    
    
    NSString *cpVfmt = [NSString stringWithFormat:@"V:|-%1.1f-[cpFull]",push];
    NSArray *fullScheduleV = [NSLayoutConstraint constraintsWithVisualFormat:cpVfmt
                                                                     options:0
                                                                     metrics:nil
                                                                       views:@{ @"cpFull" : self.cpFullDetailScreen.view }];


    [cv2u addConstraints:fConstraints];
    [cv2u addConstraints:fVConstraints];
    [cv2u addConstraints:fullScheduleV];
    
    
    [self.upcomingScreen.view layoutIfNeeded];
    [self.cpFullDetailScreen.view layoutIfNeeded];
    [self.upcomingScreen.view updateConstraintsIfNeeded];
    [self.cpFullDetailScreen.view updateConstraintsIfNeeded];
    [self.mainContentScroller layoutSubviews];
    [self.mainContentScroller updateConstraints];
    
    if ( [Utils isIOS8] ) {
        if ( [Utils isThreePointFive] ) {
            self.mainContentScroller.contentSize = CGSizeMake(self.mainContentScroller.frame.size.width*3.0,
                                                              heightHint);
        } else {
            self.mainContentScroller.contentSize = CGSizeMake(self.mainContentScroller.frame.size.width*3.0,
                                                              self.liveStreamView.frame.size.height);
        }
    } else {
        if ( [Utils isThreePointFive] ) {
            self.mainContentScroller.contentSize = CGSizeMake(self.view.frame.size.width*3.0f,
                                                              heightHint);
        } else {
            self.mainContentScroller.contentSize = CGSizeMake(self.view.frame.size.width*3.0f,
                                                              self.liveStreamView.frame.size.height);
            NSLog(@"Main Content Scroller Content Size : %1.1f width, %1.1f height",self.mainContentScroller.contentSize.width,
                  self.mainContentScroller.contentSize.height);
        }
    }
    
    [self.upcomingScreen.view printDimensionsWithIdentifier:@"Current Program View"];
    [self.cpFullDetailScreen.view printDimensionsWithIdentifier:@"Full Schedule View"];
    
    self.upcomingScreen.tableToScroll = self.mainContentScroller;
    self.mainContentScroller.delegate = self;
    
    
    NSLog(@"Main Content Scroller Content Size After Layout : %1.1f width, %1.1f height",self.mainContentScroller.contentSize.width,
          self.mainContentScroller.contentSize.height);
    
    [self.mainContentScroller printDimensionsWithIdentifier:@"Main Content Scroller"];
    [self adjustScrollingState];
    
}

- (void)scrollerTapped {
    NSLog(@" ••• TAP ••• ");
}

- (void)addPreRollController {
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) return;
    
    self.preRollViewController = [[SCPRPreRollViewController alloc] initWithNibName:nil bundle:nil];
    self.preRollViewController.delegate = self;
    
    [[NetworkManager shared] fetchTritonAd:nil completion:^(TritonAd *tritonAd) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preRollViewController.tritonAd = tritonAd;
            [self addChildViewController:self.preRollViewController];
            
            CGRect frame = self.view.bounds;
            frame.origin.y = (-1)*self.view.bounds.size.height;
            self.preRollViewController.view.frame = frame;
            
            [self.view addSubview:self.preRollViewController.view];
            [self.preRollViewController didMoveToParentViewController:self];
        });
    }];
    

}

- (void)resetUI {
    [SCPRCloakViewController cloakWithCustomCenteredView:nil useSpinner:NO blackout:YES cloakAppeared:^{
        
        self.initialPlay = NO;
        [self.jogShuttle endAnimations];
        
        [self setLiveStreamingUI:YES];
        
        if ( self.menuOpen ) {
            [self decloakForMenu:YES];
        }
        if ( self.preRollOpen ) {
            [self decloakForPreRoll:NO];
        }
        
        [[SessionManager shared] setLocalLiveTime:0.0f];
        
        [UIView animateWithDuration:0.25 animations:^{
            self.playerControlsBottomYConstraint.constant = [self.originalFrames[@"playerControls"] floatValue];
            self.liveRewindBottomYConstraint.constant = [self.originalFrames[@"liveRewind"] floatValue];
            self.programTitleYConstraint.constant = [self.originalFrames[@"programTitle"] floatValue];
            [self.liveProgressViewController hide];
            self.horizDividerLine.layer.opacity = 0.0f;
            self.initialControlsView.layer.opacity = 1.0f;
            self.initialPlayButton.layer.opacity = 1.0f;
            self.initialPlayButton.alpha = 1.0f;
        } completion:^(BOOL finished) {
            
            [self.preRollViewController.view removeFromSuperview];
            [self.preRollViewController removeFromParentViewController];
            self.preRollViewController = nil;
            
            self.navigationItem.title = kMainLiveStreamTitle;
            
            [self determinePlayState];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
                    [self addPreRollController];
                    [SCPRCloakViewController uncloak];
                    [[SessionManager shared] setExpiring:NO];
                    [[SessionManager shared] setSessionPausedDate:nil];
                }];
            });
        }];
        
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Sleep Timer
- (void)showSleepTimer {
    
    self.plainTextCountdownLabel.text = @"";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self superPop];
        if ( ![[AudioManager shared] isPlayingAudio] ) {
            if ( [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
                [self goLive:YES];
            } else {
                if ( self.initialPlay ) {
                    [self playAudio:NO];
                } else {
                    [self initialPlayTapped:nil];
                }
            }
        } else {
            if ( [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
                [self goLive:YES];
            }
        }
    });
   
}

- (void)hideSleepTimer {
    [UIView animateWithDuration:0.25 animations:^{
        self.sleepTimerContainerView.alpha = 0.0f;
    }];
}

- (void)setupTimerControls {
    self.plainTextCountdownLabel.textColor = [UIColor whiteColor];
    self.plainTextCountdownLabel.font = [[DesignManager shared] proBook:20.0f];
    self.clockIconImageView.image = [UIImage imageNamed:@"icon-stopwatch.png"];
    self.clockIconImageView.contentMode = UIViewContentModeCenter;
    self.sleepTimerCountdownProgress.progressTintColor = [UIColor whiteColor];
    self.sleepTimerCountdownProgress.trackTintColor = [UIColor clearColor];
    [self hideSleepTimer];
}

- (void)tickSleepTimer {
    CGFloat total = [[SessionManager shared] originalSleepTimerRequest]*1.0f;
    CGFloat remaining = [[SessionManager shared] remainingSleepTimerSeconds]*1.0f;
    CGFloat pct = remaining / total;
    [UIView animateWithDuration:0.25 animations:^{
        [self.sleepTimerCountdownProgress setProgress:pct];
        if ( ![self cloaked] ) {
            [self.sleepTimerContainerView setAlpha:1.0];
        }
    }];
    
    self.plainTextCountdownLabel.text = [NSDate scientificStringFromSeconds:remaining];
}

- (void)cancelSleepTimerAction {
    UIAlertView *cancelAlert = [[UIAlertView alloc] initWithTitle:@""
                                                          message:@"Are you sure you want to stop your sleep timer?"
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                                otherButtonTitles:@"Stop", nil];
    cancelAlert.tag = kCancelSleepTimerAlertTag;
    [cancelAlert show];
}

- (void)handleAlarmClock {
    [self resetUI];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self initialPlayTapped:nil];
    });
}

#pragma mark - Onboarding
- (void)primeOnboarding {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = [del masterNavigationController];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    self.liveDescriptionLabel.hidden = YES;
    self.automationMode = YES;
    self.programImageView.image = [UIImage imageNamed:@"onboarding-tile.jpg"];
    
    self.blurView.layer.opacity = 1.0f;
    
    CGFloat yOrigin = self.programImageView.frame.origin.y;
    NSLog(@"yOrigin : %1.1f",yOrigin);
    self.imageTopConstraint.constant = -36.0f;
    
    nav.navigationBarHidden = NO;
    
    self.initialControlsView.layer.opacity = 0.0f;
    self.liveStreamView.alpha = 0.0f;
    self.liveDescriptionLabel.alpha = 0.0f;
    self.pulldownMenu.alpha = 0.0f;
    
    self.programTitleLabel.font = [UIFont systemFontOfSize:30.0];
    [self.programTitleLabel proLightFontize];
    self.liveProgressViewController.view.alpha = 0.0f;
    
    [[SessionManager shared] fetchOnboardingProgramWithSegment:1 completed:^(id returnedObject) {
        [self.blurView setNeedsDisplay];
        self.programTitleLabel.text = @"";
        [SCPRCloakViewController uncloak];
        [UIView animateWithDuration:0.33 animations:^{
            self.view.alpha = 1.0f;
            [self.blurView.layer setOpacity:1.0];
            self.darkBgView.layer.opacity = 0.0f;
            [[UXmanager shared] hideMenuButton];
        } completion:^(BOOL finished) {
            [[UXmanager shared] fadeInBranding];
        }];
    }];
}

- (void)onboarding_revealPlayerControls {
    [UIView animateWithDuration:0.2 animations:^{
        self.letsGoLabel.alpha = 1.0f;
    }];
    
    POPBasicAnimation *scaleAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.duration = .45f;
    
    POPBasicAnimation *fadeIn = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeIn.fromValue = @0;
    fadeIn.toValue = @1;
    fadeIn.duration = 1.0f;
    
    [self.initialControlsView.layer pop_addAnimation:scaleAnimation forKey:@"revealPlayer"];
    [self.initialControlsView.layer pop_addAnimation:fadeIn forKey:@"playerFadeIn"];
    
}

- (void)onboarding_beginOnboardingAudio {
    
  
    [self.liveProgressViewController displayWithProgram:[[SessionManager shared] currentProgram]
                                                 onView:self.view
                                       aboveSiblingView:self.playerControlsView];
    [self.liveProgressViewController show];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveProgressViewController.view.alpha = 1.0f;
        self.liveStreamView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        [self.programTitleLabel fadeText:@"Welcome to KPCC"];
    }];
    
    [[AudioManager shared] playOnboardingAudio:1];
 
}

- (void)onboarding_rewindToBeginning {
    
}

- (void)onboarding_beginOutro {
    
    [[AudioManager shared] playOnboardingAudio:3];
}

- (void)onboarding_fin {
    
    [[AudioManager shared] resetPlayer];
    [[AudioManager shared] takedownAudioPlayer];
    
    self.initialPlay = YES;
    
    [self adjustScrubbingState];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveDescriptionLabel.alpha = 1.0f;
        [[UXmanager shared] showMenuButton];
        [self.darkBgView.layer setOpacity:0.0];
        self.onDemandPlayerView.alpha = 0.0f;
    }];
    
    [[UXmanager shared].settings setUserHasViewedOnboarding:YES];
    [[UXmanager shared] persist];
    
    [self updateDataForUI];
    
}

- (void)showOnDemandOnboarding {
    if ( ![UXmanager shared].settings.userHasViewedOnDemandOnboarding ) {
        SCPRAppDelegate *del = [Utils del];
        [del.onboardingController onboardingSwipingAction:NO];
        [del.window bringSubviewToFront:del.onboardingController.view];
        [UIView animateWithDuration:0.25 animations:^{
            del.onboardingController.view.alpha = 1.0f;
        }];
    } else if ( ![UXmanager shared].settings.userHasViewedScrubbingOnboarding ) {
        SCPRAppDelegate *del = [Utils del];
        [del.onboardingController onboardingScrubbingAction];
        [del.window bringSubviewToFront:del.onboardingController.view];
        [UIView animateWithDuration:0.25 animations:^{
            del.onboardingController.view.alpha = 1.0f;
        }];
    }
}

# pragma mark - Actions

- (IBAction)initialPlayTapped:(id)sender {
    
#ifdef DEBUG
   // [Utils crash];
#endif
    
#ifdef FORCE_TEST_STREAM
    self.preRollViewController.tritonAd = nil;
#endif
#ifdef BETA
    self.preRollViewController.tritonAd = nil;
#endif
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) {
        [[UXmanager shared] fadeOutBrandingWithCompletion:^{
            [self adjustScrubbingState];
            [self moveTextIntoPlace:YES];
            [self primePlaybackUI:YES];
            self.initialPlay = YES;
        }];
        return;
    }
    
    [[AudioManager shared] setSmooth:!self.preRollViewController.tritonAd];

    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [UIView animateWithDuration:0.15 animations:^{
            self.liveRewindAltButton.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if (self.preRollViewController.tritonAd) {
                [self cloakForPreRoll:YES];
                [self.preRollViewController primeUI:^{
                    [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
                        [self primePlaybackUI:YES];
                        [self.preRollViewController.prerollPlayer play];
                    }];
                }];
            } else {
                [self primePlaybackUI:YES];
                self.initialPlay = YES;
            }
        }];
    }];

}

- (void)specialRewind {
    self.initiateRewind = YES;
    self.preRollViewController.tritonAd = nil;
    [UIView animateWithDuration:0.15 animations:^{
        self.liveDescriptionLabel.text = @"";
    }];
    
    [self initialPlayTapped:nil];
}

- (IBAction)playOrPauseTapped:(id)sender {
    if (seekRequested) {
        seekRequested = NO;
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModePreroll ) {
        [self handlePreRollControl:([self.preRollViewController.prerollPlayer rate] == 0.0)];
        return;
    }
    
    if (![[AudioManager shared] isStreamPlaying]) {
        
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self playAudio:NO];
            return;
        }
        
        if ( [[SessionManager shared] sessionIsExpired] ) {
            [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
                [self playAudio:YES];
            }];
        } else {

            if ( self.dirtyFromFailure ) {
                self.dirtyFromFailure = NO;
                if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
                    [[QueueManager shared] playItemAtPosition:(int)[[QueueManager shared] currentlyPlayingIndex]];
                } else {
                    [self playAudio:YES];
                }
            } else {
                
                self.scrubbingTriggerView.userInteractionEnabled = YES;
                BOOL hard = [[AudioManager shared] status] == StreamStatusStopped ? YES : NO;
                [self playAudio:hard];
                
            }
            
        }
    } else {
 
        [[AudioManager shared] setUserPause:YES];
        
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            if ( [[AudioManager shared] dropoutOccurred] ) {
                [[AudioManager shared] stopAllAudio];
                [[AudioManager shared] takedownAudioPlayer];
                [[AudioManager shared] buildStreamer:kHLS];
            } else {
                [self pauseAudio];
            }
        } else {
            [self pauseAudio];
        }
#else
        [[SessionManager shared] setLastKnownPauseExplanation:PauseExplanationUserHasPausedExplicitly];
        [self pauseAudio];
#endif
        
    }
    
    [self primeManualControlButton];
    
}

- (IBAction)rewindToStartTapped:(id)sender {
    
    if ( self.jogging ) return;
    [self activateRewind:RewindDistanceBeginning];
    
}

- (IBAction)prevEpisodeTapped:(id)sender {
    [[QueueManager shared] playPrev];
}
- (IBAction)nextEpisodeTapped:(id)sender {
    [[QueueManager shared] playNext];
}

/**
 * For MPRemoteCommandCenter - see [self primeRemoteCommandCenter]
 */
- (void)pauseTapped:(id)sender {
    NSLog(@" >>>>>> EVENT RECEIVED FROM COMMAND CENTER REMOTE <<<<<< ");
    // Disabling this, seems redundant from the other remote control handling
    // [self remoteControlPlayOrPause];
}
- (void)playTapped:(id)sender {
    NSLog(@" >>>>>> EVENT RECEIVED FROM COMMAND CENTER REMOTE <<<<<< ");
    // Disabling this, seems redundant from the other remote control handling
    // [self remoteControlPlayOrPause];
}

- (void)snapJogWheel {
    UIImage *img = self.playPauseButton.imageView.image;
    CGFloat width = img.size.width;
    CGFloat height = img.size.height;
    [self.rewindWidthConstraint setConstant:width];
    [self.rewindHeightContraint setConstant:height];
    [self.rewindView layoutIfNeeded];
    [self.playerControlsView layoutIfNeeded];
}


- (NSTimeInterval)rewindAgainstStreamDelta {
    AVPlayerItem *item = [[AudioManager shared].audioPlayer currentItem];
    NSTimeInterval current = [item.currentDate timeIntervalSince1970];
    
    if ( [[SessionManager shared] currentProgram] ) {
        NSTimeInterval startOfProgram = [[[[SessionManager shared] currentProgram] soft_starts_at] timeIntervalSince1970];
        return current - startOfProgram;
    }
    
    return (NSTimeInterval)0;
    
}

- (BOOL)uiIsJogging {
    if ( [self.liveDescriptionLabel.text isEqualToString:kRewindingText] ) return YES;
    if ( [self.liveDescriptionLabel.text isEqualToString:kForwardingText] ) return YES;
    return NO;
}

-(void)skipBackwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    [self rewindFifteen];
}

-(void)skipForwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    [self fastForwardFifteen];
}

- (IBAction)backToLiveTapped:(id)sender {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self activateFastForward];
    }];
}

- (IBAction)shareButtonTapped:(id)sender {
    if (self.onDemandProgram && self.onDemandEpUrl) {
        
        NSString *pt = @"";
        NSString *et = @"";
        et = [[[QueueManager shared] currentChunk] audioTitle];
        pt = [[[QueueManager shared] currentChunk] programTitle];
        NSString *complete = [NSString stringWithFormat:@"%@ - %@ - %@",et,pt,self.onDemandEpUrl];
        
        UIActivityViewController *controller = [[UIActivityViewController alloc]
                                                initWithActivityItems:@[complete]
                                                applicationActivities:nil];
        
        controller.excludedActivityTypes = @[UIActivityTypeAirDrop];
        [controller setCompletionHandler:^(NSString *activityType, BOOL completed) {
            if ( completed ) {
                
                NSArray *activityTokens = [[activityType capitalizedString] componentsSeparatedByString:@"."];
                NSString *usable = activityTokens.count > 1 ? activityTokens.lastObject : [activityType capitalizedString];
                [[AnalyticsManager shared] logEvent:[NSString stringWithFormat:@"episodeShared%@",usable]
                                     withParameters:@{ @"episodeUrl" : self.onDemandEpUrl,
                                                       @"episodeTitle" : self.onDemandProgram.title,
                                                       @"programTitle" : pt }];
            }
        }];
        
        [self presentViewController:controller animated:YES completion:^{
            
            [[DesignManager shared] normalizeBar];
            
        }];
    }
}

- (IBAction)showPreRollTapped:(id)sender {
    [self cloakForPreRoll:YES];
    [self.preRollViewController primeUI:^{
        [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
            
        }];
    }];
}

# pragma mark - Audio commands
- (void)playAudio:(BOOL)hard {
    
    [[AudioManager shared] setUserPause:NO];
    
    if ( hard && ![[SessionManager shared] sessionIsInBackground] ) {
        [[AudioManager shared] playLiveStream];
    } else {
        [[AudioManager shared] playAudio];
    }
    
}

- (void)pauseAudio {
    [[AudioManager shared] pauseAudio];
}

- (void)rewindFifteen {
    seekRequested = YES;
    [[AudioManager shared] backwardSeekFifteenSecondsWithCompletion:^{
        
    }];
}

- (void)fastForwardFifteen {
    seekRequested = YES;
    [[AudioManager shared] forwardSeekFifteenSecondsWithCompletion:^{
        
    }];
}

- (void)goLive:(BOOL)play {
    [self goLive:play smooth:YES];
}

- (void)goLive:(BOOL)play smooth:(BOOL)smooth {
    
    [[AudioManager shared] setSmooth:smooth];
    [self.liveProgressViewController hide];
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ||
        [[AudioManager shared] currentAudioMode] == AudioModeNeutral ) {
        if ( [[AudioManager shared] status] == StreamStatusPaused ) {
            if ( self.initialPlay ) {
                [self playAudio:NO];
            } else {
                [self initialPlayTapped:nil];
            }
            return;
        }
        if ( [[AudioManager shared] status] == StreamStatusStopped ) {
            if ( self.initialPlay ) {
                [self playAudio:YES];
            } else {
                [self initialPlayTapped:nil];
            }
            return;
        }
        
        return;
    }
    
    [[AnalyticsManager shared] endTimedEvent:@"episodePlay"];
    [[AudioManager shared] stopAudio];
    
    self.liveStreamView.userInteractionEnabled = YES;
    self.playerControlsView.userInteractionEnabled = YES;
    self.lockPlayback = !play;
    
    [self.jogShuttle endAnimations];
    
    if ( [self cloaked] ) {
        [self decloakForXFS];
    }
    
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        
        [self setLiveStreamingUI:YES];
        [self treatUIforProgram];
        
        if ( play ) {
            if ( self.initialPlay ) {
                [self playAudio:YES];
            } else {
                [self initialPlayTapped:nil];
            }
        }
        
    }];
    
}

- (void)activateRewind:(RewindDistance)distance {
    
    self.initiateRewind = NO;
    self.preRollViewController.tritonAd = nil;
    [self snapJogWheel];
    
    self.jogShuttle.forceSingleRotation = YES;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.liveRewindAltButton.alpha = 0.0f;
        if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
            self.queueBlurView.alpha = 1.0f;
        }
    }];
    
    self.jogging = YES;
    self.shuttlingGate = YES;
    
    [[AudioManager shared] setCalibrating:YES];
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    Program *cProgram = [[SessionManager shared] currentProgram];
    [self.jogShuttle.view setAlpha:1.0f];
    
    BOOL sound = [AudioManager shared].currentAudioMode == AudioModeOnboarding ? NO : YES;
    [self.jogShuttle animateWithSpeed:0.8f
                         hideableView:self.playPauseButton
                            direction:SpinDirectionBackward
                            withSound:sound
                           completion:^{
                               
                               self.dirtyFromRewind = YES;
                               self.initiateRewind = NO;
                               self.jogging = NO;
                               
                               [self updateControlsAndUI:YES];
                               
                               if ( [[UXmanager shared] userHasSeenOnboarding] ) {
                                   
                                   if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
                                       [UIView animateWithDuration:0.25 animations:^{
                                           self.queueBlurView.alpha = 0.0f;
                                       }];
                                   }
                                   
                                   [[SessionManager shared] invalidateSession];
                                   [[SessionManager shared] setRewindSessionIsHot:YES];
                                   [self primeManualControlButton];
                                   
                                   [[AudioManager shared] adjustAudioWithValue:0.1f completion:^{
                                       
                                   }];
                                   
                               } else {
                                   
                                   [[SessionManager shared] fetchOnboardingProgramWithSegment:2 completed:^(id returnedObject) {
                                       
                                       [[AudioManager shared] playOnboardingAudio:2];
                                       
                                   }];
                                   
                               }
                               
                           }];
    
    [self.liveProgressViewController rewind];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        switch (distance) {
            case RewindDistanceFifteen:
                [self rewindFifteen];
                break;
            case RewindDistanceThirty:
                break;
            case RewindDistanceOnboardingBeginning:
            {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.jogShuttle endAnimations];
                });
                break;
            }
            case RewindDistanceBeginning:
            default:
                if (cProgram) {
                    [[AudioManager shared] backwardSeekToBeginningOfProgram];
                } 
                break;
                
        }
        
        
    });
    
}

- (void)activateFastForward {
    [self snapJogWheel];
    
    if ( !setForOnDemandUI ) {
        self.jogging = YES;
        [self.liveDescriptionLabel pulsate:kForwardingText color:nil];
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        self.liveRewindAltButton.alpha = 0.0f;
        if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
            self.queueBlurView.alpha = 1.0f;
        }
    }];
    
    self.shuttlingGate = YES;
    [[AudioManager shared] setCalibrating:YES];
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    [self.jogShuttle.view setAlpha:1.0];
    [[SessionManager shared] setSeekForwardRequested:YES];
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self.jogShuttle animateWithSpeed:0.8
                             hideableView:self.playPauseButton
                                direction:SpinDirectionForward
                                withSound:YES
                               completion:^{
                                   
                                   self.jogging = NO;
                                   self.dirtyFromRewind = NO;
                                   [self updateControlsAndUI:YES];
                                   
                                   [[SessionManager shared] setSeekForwardRequested:NO];
                                   [[SessionManager shared] invalidateSession];
                                   [self primeManualControlButton];
                                   
                                   if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
                                       [UIView animateWithDuration:0.25 animations:^{
                                           self.queueBlurView.alpha = 0.0f;
                                       }];
                                   }
                                   
                                   [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                       [self.view bringSubviewToFront:self.playerControlsView];
                                   }];
                                   
                               }];
        
        
        [self.liveProgressViewController forward];
        
    }];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.66 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        [[AudioManager shared] forwardSeekLiveWithType:ScrubbingTypeBackToLive
                                            completion:nil];
        
    });
}

- (void)handlePreRollControl:(BOOL)paused {
    if ( !paused ) {
        [self.preRollViewController.prerollPlayer pause];
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
    } else {
        [self.preRollViewController.prerollPlayer play];
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
    }
}

#pragma mark - Scrubbing
- (void)primeScrubber {
    
    SCPRScrubbingUIViewController *sUI = [[SCPRScrubbingUIViewController alloc]
                                          init];
    sUI.view = self.scrubbingUIView;
    
    self.scrubbingUI = sUI;
    self.scrubbingUI.rw30Button = self.mainBackward30Button;
    self.scrubbingUI.fw30Button = self.mainForward30Button;

    self.scrubbingUI.lowerBoundLabel = self.lowerBoundScrubberLabel;
    self.scrubbingUI.upperBoundLabel = self.upperBoundScrubberLabel;
    self.scrubbingUI.timeBehindLiveLabel = self.timeBehindLiveScrubberLabel;
    self.scrubbingUI.timeNumericLabel = self.timeNumbericScrubberLabel;
    self.scrubbingUI.captionLabel = self.scrubberTimeLabel;
    self.scrubbingUI.liveProgressView = self.liveProgressScrubberView;
    self.scrubbingUI.liveStreamProgressAnchor = self.liveProgressScrubberAnchor;
    self.scrubbingUI.liveProgressNeedleReadingLabel = self.liveProgressNeedleReadingLabel;
    self.scrubbingUI.liveProgressNeedleView = self.liveProgressNeedleView;
    self.scrubbingUI.flagAnchor = self.flagAnchor;
    self.scrubbingUI.currentProgressNeedleView = self.currentProgressNeedleView;
    self.scrubbingUI.currentProgressReadingLabel = self.currentProgressNeedleReadingLabel;
    self.scrubbingUI.scrubbingAvailable = YES;
    
    if ( [Utils isThreePointFive] ) {
        self.topGapScrubbingAnchor.constant = 54.0f;
    }
    
    SCPRScrubberViewController *sCtrl = [[SCPRScrubberViewController alloc]
                                         init];
    sCtrl.view = self.scrubberControlView;
    
    self.scrubbingUI.scrubberController = sCtrl;
    self.scrubbingUI.scrubberController.viewAsTouchableScrubberView = self.touchableScrubberView;
    
    if ( self.scrubbingTriggerView ) {
        [self.scrubbingTriggerView removeFromSuperview];
    }
    self.scrubbingTriggerView = [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,self.view.frame.size.width,
                                                            40.0)];
#ifdef TESTING_SCRUBBER
    self.scrubbingTriggerView.backgroundColor = [[UIColor purpleColor] translucify:0.33];
#else
    self.scrubbingTriggerView.backgroundColor = [UIColor clearColor];
#endif
    
    UIPanGestureRecognizer *pgr = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(bringUpScrubber)];

    [self.scrubbingTriggerView addGestureRecognizer:pgr];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                       action:@selector(bringUpScrubber)];
    lpgr.minimumPressDuration = 0.25;
    [self.scrubbingTriggerView addGestureRecognizer:lpgr];
    
    CGFloat adjustment = [Utils isThreePointFive] ? 70.0 : 0.0f;
    self.scrubbingTriggerView.frame = CGRectMake(0.0, self.progressView.frame.origin.y-self.scrubbingTriggerView.frame.size.height+20.0-adjustment,
                                                 self.scrubbingTriggerView.frame.size.width,
                                                 self.scrubbingTriggerView.frame.size.height);
    
    [self.view addSubview:self.scrubbingTriggerView];
    
    self.back30VerticalAnchor.constant = [Utils isThreePointFive] ? 28.0 : 40.0f;
    self.fwd30VerticalAnchor.constant = [Utils isThreePointFive] ? 28.0 : 40.0f;
    self.scrubbingUI.parentControlView = self;
    
    [self adjustScrubbingState];
    
    sUI.view.alpha = 0.0f;


    [self.scrubbingUI prerender];
    
}

- (void)bringUpScrubber {
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnDemand &&
        [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
        return;
    }
    
    if ( !self.scrubbingUI.scrubbingAvailable ) return;
    
    if ( [[SessionManager shared] sessionHasNoProgram] ) {
        return;
    }
    
    if ( self.scrubberLoadingGate ) return;
    
    [self wipeTargetsForScrubButtons];
    
    self.scrubberLoadingGate = YES;
    self.scrubbingUI.playPauseButton = self.playPauseButton;
    
    [self.scrubbingUI primeForAudioMode];
    
    [[AudioManager shared] setDelegate:self.scrubbingUI];
    
    if ( [Utils isThreePointFive] ) {
        //self.topYScrubbingAnchor.constant = [self.topYScrubbingAnchor constant]-kScrubbingThreeFiveSlip;
        self.playerControlsBottomYConstraint.constant = [self.playerControlsBottomYConstraint constant]+kScrubbingThreeFiveSlip;
        [self.scrubbingUI.view layoutIfNeeded];
    }
    
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [[DesignManager shared] fauxHideNavigationBar:self];
        [self cloakForScrubber];
        
        if ( [Utils isThreePointFive] ) {
            [self.view updateConstraintsIfNeeded];
            [self.view layoutIfNeeded];
        }
        
        [self.scrubbingUI scrubberWillAppear];
        self.scrubbingUI.view.alpha = 1.0f;
        [self.scrubbingUI.scrubberController unmask];
        
    } completion:^(BOOL finished) {
        
        if ( [Utils isThreePointFive] ) {
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.8f, 0.8f)];
            scaleAnimation.springBounciness = 2.0f;
            scaleAnimation.springSpeed = 1.0f;
            [self.playPauseButton.layer pop_addAnimation:scaleAnimation forKey:@"squeeze-play-button"];
        }
        
        [self addCloseButton];
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [self.scrubbingUI tickLive:NO];
        }
    }];
    
}


- (void)cloakForScrubber {

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        SCPRQueueScrollableView *cv = self.queueUIContents[self.queueCurrentPage];
        cv.audioTitleLabel.alpha = 0.6;
    }
    
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        // No-op right now
    }
    
    [self pushToHiddenVector:self.horizDividerLine];
    [self pushToHiddenVector:self.timeLabelOnDemand];
    [self pushToHiddenVector:self.onDemandPlayerView];
    [self pushToHiddenVector:self.progressView];
    [self pushToHiddenVector:self.liveProgressViewController.view];
    [self pushToHiddenVector:self.liveDescriptionLabel];
    [self pushToHiddenVector:self.scrubbingTriggerView];
    [self pushToHiddenVector:self.programTitleLabel];
    [self pushToHiddenVector:self.liveRewindAltButton];
    [self pushToHiddenVector:self.shareButton];
    [self pushToHiddenVector:self.sleepTimerContainerView];
    [self pushToHiddenVector:[[[Utils del] xfsInterface] view]];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.queueBlurView.alpha = 1.0f;
        self.queueDarkBgView.alpha = 0.45f;
    }];

    
    self.queueScrollView.userInteractionEnabled = NO;
    self.scrubbing = YES;
    [self commitHiddenVector];
}

- (void)decloakForScrubber {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        SCPRQueueScrollableView *cv = self.queueUIContents[self.queueCurrentPage];
        cv.audioTitleLabel.alpha = 1.0f;
    }
    
    [self popHiddenVector];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.queueBlurView.alpha = 0.0f;
        self.queueDarkBgView.alpha = 0.0f;
    }];
    
    self.queueScrollView.userInteractionEnabled = YES;
    
    self.scrubbing = NO;
}

- (void)addCloseButton {
    if ( self.scrubberCloseButton ) {
        [self.scrubberCloseButton removeFromSuperview];
    }
    
    self.scrubberCloseButton = [SCPRButton buttonWithType:UIButtonTypeCustom];
    
    [self.scrubberCloseButton setImage:[UIImage imageNamed:@"btn_close.png"]
                              forState:UIControlStateNormal];
    [self.scrubberCloseButton setImage:[UIImage imageNamed:@"btn_close.png"]
                              forState:UIControlStateHighlighted];
    
    [self.scrubbingUI setCloseButton:self.scrubberCloseButton];
    
    [self.view addSubview:self.scrubberCloseButton];
    
    self.scrubberCloseButton.contentMode = UIViewContentModeCenter;
    
    self.scrubberCloseButton.alpha = 0.0f;
    
    [self.scrubberCloseButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    /*NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[button(40.0)]-20-|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:@{ @"button" : self.scrubberCloseButton }];*/
    
    NSLayoutConstraint *centerAnchor = [NSLayoutConstraint constraintWithItem:self.scrubberCloseButton
                                                                    attribute:NSLayoutAttributeCenterX
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:self.view
                                                                    attribute:NSLayoutAttributeCenterX
                                                                   multiplier:1.0
                                                                     constant:0.0];
    
    NSLayoutConstraint *widthAnchor = [NSLayoutConstraint constraintWithItem:self.scrubberCloseButton
                                                                   attribute:NSLayoutAttributeWidth
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:nil
                                                                   attribute:NSLayoutAttributeNotAnAttribute
                                                                  multiplier:1.0f
                                                                    constant:40.0f];
    
#ifdef TESTING_SCRUBBER
    self.scrubberCloseButton.backgroundColor = [[UIColor kpccPeriwinkleColor] translucify:0.66f];
#endif
    
    [self.scrubberCloseButton addConstraint:widthAnchor];
    
    CGFloat btnSize = [Utils isThreePointFive] ? 32.0 : 40.0f;
    CGFloat bottomAnchorConstant = [Utils isThreePointFive] ? 8.0 : 14.0f;
    
    NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:[button(%1.1f)]-%1.1f-|",btnSize,bottomAnchorConstant]
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"button" : self.scrubberCloseButton }];
    [self.view addConstraint:centerAnchor];
    [self.view addConstraints:vConstraints];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.scrubberCloseButton.alpha = 1.0f;
    }];
    
}

- (void)killCloseButton {

    [UIView animateWithDuration:0.25 animations:^{
        [self.scrubberCloseButton setAlpha:0.0];
    } completion:^(BOOL finished) {
        [self.scrubberCloseButton removeFromSuperview];
    }];
    
}

- (void)finishedWithScrubber {
    
    [self wipeTargetsForScrubButtons];
    
    [self.mainBackward30Button addTarget:self
                                  action:@selector(seekBack30)
                        forControlEvents:UIControlEventTouchUpInside
                                 special:YES];
    
    [self.mainForward30Button addTarget:self
                                 action:@selector(seekFwd30)
                       forControlEvents:UIControlEventTouchUpInside
                                special:YES];
    
    [UIView animateWithDuration:0.25 animations:^{

        
        
        if ( [Utils isThreePointFive] ) {
            self.playerControlsBottomYConstraint.constant = [self.playerControlsBottomYConstraint constant]-kScrubbingThreeFiveSlip;
            [self.view layoutIfNeeded];
        }
        
        [self.scrubbingUI takedown];
        SCPRQueueScrollableView *cqsv = self.queueUIContents[self.queueCurrentPage];
        cqsv.audioTitleLabel.alpha = 1.0f;
        self.scrubberLoadingGate = NO;
        
    } completion:^(BOOL finished) {
        
        if ( [Utils isThreePointFive] ) {
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
            [self.playPauseButton.layer pop_addAnimation:scaleAnimation forKey:@"squeeze-play-button"];
        }
        
        [self primeManualControlButton];
     
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AudioManager shared] setDelegate:self];
            if ( ![[AudioManager shared] isPlayingAudio] ) {
                if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
                    [self tickOnDemand];
                }
            }
        });

    }];
}

- (void)beginScrubbingWaitMode {
    if ( ![self.jogShuttle spinning] ) {
        [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
            self.playPauseButton.enabled = YES;
        }];
    }
}

- (void)endScrubbingWaitMode {
    [self.jogShuttle endAnimations];
}

- (void)seekBack30 {
    
    [[AudioManager shared] setIgnoreDriftTolerance:YES];
    [[AudioManager shared] backwardSeekThirtySecondsWithCompletion:^{
        [self primeManualControlButton];
    }];
    
}

- (void)seekFwd30 {
    [[AudioManager shared] setIgnoreDriftTolerance:NO];
    [[AudioManager shared] forwardSeekThirtySecondsWithCompletion:^{
        [self primeManualControlButton];
    }];
}

- (void)animatedStateForForwardButton:(BOOL)enabled {
    [self animatedStateForButton:self.mainForward30Button
                         enabled:enabled];
}

- (void)animatedStateForBackwardButton:(BOOL)enabled {
    [self animatedStateForButton:self.mainBackward30Button
                         enabled:enabled];
}

- (void)animatedStateForButton:(UIButton *)button enabled:(BOOL)enabled {
    
    CGFloat stateAlpha = button.alpha == 0.0f ? 0.0f : 1.0f;
    [UIView animateWithDuration:0.33f animations:^{
        button.alpha = enabled ? stateAlpha : 0.4f;
    }];

    button.userInteractionEnabled = enabled;
    
}

- (void)wipeTargetsForScrubButtons {
    [self.mainForward30Button removeTarget:nil
                                    action:nil
                          forControlEvents:UIControlEventAllEvents];
    
    [self.mainBackward30Button removeTarget:nil
                                     action:nil
                           forControlEvents:UIControlEventAllEvents];
}

# pragma mark - UI control
- (void)prettifyBehindLiveStatus {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        [self adjustScrubbingState];
        return;
    }
    
    NSDate *ciCurrentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    if ( !ciCurrentDate ) {
        self.liveDescriptionLabel.text = @"";
        return;
    }
    
    if ( [[AudioManager shared] calibrating] ) {
        return;
    }
    
#ifndef SUPPRESS_V_LIVE
    NSTimeInterval ti = [[[SessionManager shared] vLive] timeIntervalSinceDate:ciCurrentDate];
#else
    NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:ciCurrentDate];
#endif
    
#ifndef SUPPRESS_V_LIVE
    if ( ti > 60*60*48 ) {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            [self.liveDescriptionLabel fadeText:@"UP NEXT"];
        } else {
            [self.liveDescriptionLabel fadeText:@"LIVE"];
            self.dirtyFromRewind = NO;
        }
        
        [self adjustScrubbingState];
        
        return;
    }
#endif
    
    if ( [[NetworkManager shared] networkDown] ) {
        [self.liveDescriptionLabel fadeText:@"NO NETWORK"];
        return;
    }
    
    if ( ti > kVirtualMediumBehindLiveTolerance || [[AudioManager shared] ignoreDriftTolerance] ) {
        [self.liveDescriptionLabel fadeText:[NSString stringWithFormat:@"%@ BEHIND LIVE", [NSDate prettyTextFromSeconds:ti]]];
        self.previousRewindThreshold = [[AudioManager shared].audioPlayer.currentItem.currentDate timeIntervalSince1970];
        

    } else {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            [self.liveDescriptionLabel fadeText:@"UP NEXT"];
        } else {
            [self.liveDescriptionLabel fadeText:@"LIVE"];
            self.dirtyFromRewind = NO;
        }
        
    }
    
    [self adjustScrubbingState];
}

- (void)updateDataForUI {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        if ( returnedObject ) {
            
            [self.liveProgressViewController displayWithProgram:(Program*)returnedObject
                                                         onView:self.view
                                               aboveSiblingView:self.playerControlsView];
            [self.liveProgressViewController hide];
            [self determinePlayState];
            
            //[self.upcomingScreen primeWithProgramBasedOnCurrent:returnedObject];
            [self.cpFullDetailScreen setupSchedule];
            
            if ( [[Utils del] userRespondedToPushWhileClosed] ) {
                [[Utils del] setUserRespondedToPushWhileClosed:NO];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSLog(@" >>>>> READY TO PLAY STREAM <<<<< ");
                    [self handleResponseForNotification];
                });
            }
            
            if ( [[UXmanager shared] onboardingEnding] ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self primeManualControlButton];
                });
            }
            
        } else {
            
            [self determinePlayState];
            
        }
    }];
}


- (void)moveTextIntoPlace:(BOOL)animated {
    
    CGFloat constant = self.initialProgramTitleConstant;
    if ( self.programTitleYConstraint.constant == constant ) return;
    if ( !animated ) {
        [self.programTitleYConstraint setConstant:constant];
    } else {
        
        POPSpringAnimation *programTitleAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
        programTitleAnim.toValue = @(constant);
        [self.programTitleYConstraint pop_addAnimation:programTitleAnim forKey:@"animateProgramTitleDown"];
        
        POPBasicAnimation *fadeControls = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        fadeControls.toValue = @(0);
        
        [self.initialControlsView.layer pop_addAnimation:fadeControls forKey:@"fadeDownInitialControls"];
        [self.programTitleYConstraint pop_addAnimation:programTitleAnim forKey:@"animateProgramTitleDown"];
        
    }
    
}

- (void)updateControlsAndUI:(BOOL)animated {
    
    // First set contents of background, live-status labels, and play button.
    [self setUIContents:animated];
    
}

- (void)setUIContents:(BOOL)animated {
    
    if ( self.jogging || self.queueBlurShown ) {
        return;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.1 animations:^{
            
            if ( !self.menuOpen && ![[UXmanager shared] notificationsPromptDisplaying] && !self.scrubbing )
                self.liveDescriptionLabel.alpha = 1.0f;
            
        } completion:^(BOOL finished) {
            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
            } else {
                [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
            }
            
            
            [UIView animateWithDuration:0.1 animations:^{
                if ( [AudioManager shared].currentAudioMode != AudioModeOnDemand ) {
                    [self.playPauseButton setAlpha:1.0];
                }
            }];
            
        }];
    }
}

- (void)setUIPositioning {
    
}

- (void)determinePlayState {
    
    if ( [[AudioManager shared] seekWillEffectBuffer] ) return;
    
    if ( [[AudioManager shared] status] == StreamStatusStopped || self.dirtyFromFailure || [[SessionManager shared] expiring] ) {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            self.liveDescriptionLabel.text = @"UP NEXT";
        } else {
            if ( [AudioManager shared].currentAudioMode != AudioModeOnboarding )
                self.liveDescriptionLabel.text = @"ON NOW";
        }
    }
    if ( [[AudioManager shared] status] == StreamStatusPaused ) {
        if ( [[SessionManager shared] sessionIsBehindLive] ) {
#ifndef SUPPRESS_V_LIVE
            [self prettifyBehindLiveStatus];
#else
            NSDate *ciCurrentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
            NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:ciCurrentDate];
            if ( ti > [[SessionManager shared] peakDrift] ) {
                [self.liveDescriptionLabel setText:[NSString stringWithFormat:@"%@ BEHIND LIVE", [NSDate prettyTextFromSeconds:ti]]];
            } else {
                [self.liveDescriptionLabel setText:[NSString stringWithFormat:@"LIVE"]];
            }
#endif
        }
    }
    
    if ( self.liveDescriptionLabel.hidden ) {
        [self.liveDescriptionLabel setHidden:NO];
    }
    
    if ( [[NetworkManager shared] networkDown] ) {
       self.liveDescriptionLabel.text = @"NO NETWORK";
    }
    
    [self primeManualControlButton];
}

/**
 * Dev note: Not being called for now.. zooms in background program image slightly
 */
- (void)scaleBackgroundImage {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    
    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
    } else {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    }
    
    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 2.0f;
    
    // Used to ensure animation only gets started once.
    // This method stems from onRateChange: firing, which sometimes gets called rapidly.
    [scaleAnimation setCompletionBlock:^(POPAnimation *animation, BOOL done) {
        busyZoomAnim = NO;
    }];
    
    if (!seekRequested && !busyZoomAnim) {
        busyZoomAnim = YES;
        [self.programImageView.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
    }
}

- (void)setLiveStreamingUI:(BOOL)animated {
    
    setForOnDemandUI = NO;
    setForLiveStreamUI = YES;
    self.onDemandFailing = NO;
    self.scrubbingUIView.alpha = 0.0f;
    self.queueBlurShown = NO;
    self.dividerLineRightAnchor.constant = -5.0f;
    self.dividerLineLeftAnchor.constant = 5.0f;
    
    self.navigationItem.title = kMainLiveStreamTitle;
    [self primeRemoteCommandCenter:YES];
    
    self.mainContentScroller.alpha = 1.0f;
    
    if (![self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:YES];
        setForOnDemandUI = NO;
    }
    
    if (![self.timeLabelOnDemand isHidden]) {
        [self.timeLabelOnDemand setHidden:YES];
    }
    
    if (![self.progressView isHidden]) {
        [self.progressView setHidden:YES];
    }
    
    if (![self.queueScrollView isHidden]) {
        [self.queueScrollView setHidden:YES];
    }
    
    self.queueBlurView.alpha = 0.0f;
    self.queueDarkBgView.alpha = 0.0f;
    self.shareButton.alpha = 0.0f;
    
    setForLiveStreamUI = YES;
    
    [self moveTextIntoPlace:NO];
    
    [self.view layoutIfNeeded];
    
    
    if ( self.initialPlay ) {
        self.programTitleYConstraint.constant = self.deployedProgramTitleConstant;
    } else {
        self.programTitleYConstraint.constant = self.initialProgramTitleConstant;
    }
    
    [self.view layoutIfNeeded];
    
    self.liveDescriptionLabel.text = @"LIVE";
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    
    [[AnalyticsManager shared] screen:@"liveStreamView"];
    
}


- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index {
    
    [[AudioManager shared] invalidateTimeObserver];
    
    if ( self.preRollViewController.tritonAd )
        self.preRollViewController.tritonAd = nil;
    
    self.queueBlurShown = NO;
    
    if ( [[AudioManager shared] isPlayingAudio] ) {
        self.onDemandPanning = YES;
    }
    
    [self snapJogWheel];
    
    self.onDemandGateCount = 0;
    self.queueBlurView.alpha = 1.0f;
    self.queueBlurView.layer.opacity = 1.0f;
    
    if ([self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:NO];
    }
    
    if ([self.mainContentScroller alpha] != 0.0f) {
        self.mainContentScroller.alpha = 0.0f;
        setForLiveStreamUI = NO;
    }
    
    if ([self.timeLabelOnDemand isHidden]) {
        [self.timeLabelOnDemand setHidden:NO];
    }
    
    if ([self.progressView isHidden]) {
        [self.progressView setHidden:NO];
    }
    
    self.onDemandPlayerView.backgroundColor = [UIColor clearColor];
    self.timeLabelOnDemand.text = @"LOADING...";
    self.queueLoading = YES;
    

    
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    UIImage *img = [[DesignManager shared] currentBlurredImage];
    self.queueBlurView.image = img;
    [[DesignManager shared] setProtectBlurredImage:YES];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.jogShuttle.view.alpha = 1.0f;
        self.timeLabelOnDemand.alpha = 1.0f;
        self.queueBlurView.layer.opacity = 1.0f;
        
        self.liveProgressViewController.view.alpha = 0.0f;
        [self.liveProgressViewController hide];
        self.shareButton.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
        [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
            self.playPauseButton.enabled = YES;
            if ( !self.onDemandFailing ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self setUIContents:YES];
                });
            }
        }];
        
        setForOnDemandUI = YES;
        setForLiveStreamUI = NO;
        
        if (self.menuOpen) {
            [self decloakForMenu:NO];
        }
        
        [[Utils del] controlXFSAvailability:NO];
        [self adjustScrubbingState];
        
        [[SessionManager shared] setCurrentProgram:nil];
        
        self.navigationItem.title = @"Programs";
        [self.progressView setProgress:0.0 animated:YES];
        
        self.progressView.alpha = 1.0f;
        self.queueScrollView.alpha = 1.0f;
        self.onDemandPlayerView.alpha = 1.0f;
        self.queueDarkBgView.alpha = 0.0f;
        
        [self primeRemoteCommandCenter:NO];
        
        // Make sure the larger play button is hidden ...
        if ( !self.initialPlay ) {
            [self primePlaybackUI:NO];
        }
        
        initialPlay = YES;
        
        for (UIView *v in [self.queueScrollView subviews]) {
            [v removeFromSuperview];
        }
        
        self.queueContents = array;
        self.queueUIContents = [NSMutableArray new];
        for (int i = 0; i < [array count]; i++) {
            CGRect frame;
            frame.origin.x = self.queueScrollView.frame.size.width * i;
            frame.origin.y = 0;
            frame.size = self.queueScrollView.frame.size;
            
            SCPRQueueScrollableView *queueSubView = [[SCPRQueueScrollableView alloc] initWithFrame:frame];
            [queueSubView setAudioChunk:array[i]];
            
            [self.queueUIContents addObject:queueSubView];
            [self.queueScrollView addSubview:queueSubView];
        }
        
        self.queueScrollView.contentSize = CGSizeMake(self.queueScrollView.frame.size.width * [array count], self.queueScrollView.frame.size.height);
        [self setPositionForQueue:index animated:NO];
        [self.queueScrollView setHidden:NO];
        
        __block SCPRMasterViewController *weakSelf = self;
        [self setDataForOnDemand:program andAudioChunk:array[index] completion:^{
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                weakSelf.progressView.alpha = 0.0f;
                weakSelf.shareButton.alpha = 0.0f;
                weakSelf.liveProgressViewController.view.alpha = 0.0f;
            } completion:^(BOOL finished){
                
                weakSelf.queueBlurShown = YES;
                
                [[AudioManager shared] setCurrentAudioMode:AudioModeOnDemand];
                [weakSelf.navigationController popToRootViewControllerAnimated:YES];
                
                [weakSelf.view bringSubviewToFront:weakSelf.scrubbingTriggerView];
                
                [[DesignManager shared] setProtectBlurredImage:NO];
                
                NSString *pt = program.title;
                pt = [pt stringByReplacingOccurrencesOfString:@" "
                                                   withString:@""];
                NSString *token = [NSString stringWithFormat:@"%@%@",@"onDemandView",pt];
                
                [[AnalyticsManager shared] screen:token];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[QueueManager shared] playItemAtPosition:index];
                    weakSelf.onDemandPanning = NO;
                });
                
            }];
        }];
    }];
    
}

- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk completion:(CompletionBlock)completion {
    if (program != nil) {
        self.onDemandProgram = program;
        self.onDemandEpUrl = audioChunk.contentShareUrl;
        [[AudioManager shared] updateNowPlayingInfoWithAudio:audioChunk];
        [[DesignManager shared] loadProgramImage:program.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              [self.queueBlurView setNeedsDisplay];
                                              [self.programTitleOnDemand setText:[program.title uppercaseString]];
                                              if ( completion ) {
                                                  completion();
                                              }
                                          });
                                      }];
    }
}

- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk *)audioChunk {
    [self setDataForOnDemand:program
               andAudioChunk:audioChunk
                  completion:nil];
}

- (void)setPositionForQueue:(int)index animated:(BOOL)animated {
    if ( !self.jogShuttle.spinning ) {
        [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
            self.playPauseButton.enabled = YES;
            [self updateControlsAndUI:YES];
        }];
    }
    if (index >= 0 && index < [self.queueScrollView.subviews count]) {
        if (animated) {
            [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.queueScrollView.contentOffset = CGPointMake(self.queueScrollView.frame.size.width * index, 0);
            } completion:^(BOOL finished) {
                self.queueCurrentPage = index;
            }];
        } else {
            self.queueScrollView.contentOffset = CGPointMake(self.queueScrollView.frame.size.width * index, 0);
            self.queueCurrentPage = index;
        }
    }
    [self.queueScrollView layoutIfNeeded];
    
    if ( self.scrubbing ) {
        [self.scrubbingUI muteUI];
    }
}

- (void)treatUIforProgram {
    Program *programObj = [[SessionManager shared] currentProgram];
    // Only update background image when we're not in On Demand mode.
    if (!setForOnDemandUI){
        
        if ( !programObj || SEQ(programObj.program_slug,@"kpcc-live") ) {
            [self updateUIWithProgram:programObj];
            [[SessionManager shared] setGenericImageForProgram:YES];
            self.programImageView.image = [UIImage imageNamed:@"program_tile_generic.jpg"];
            [self finishUpdatingForProgram];
            return;
        }
        

        
        [[DesignManager shared] loadProgramImage:programObj.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          
                                          [self updateUIWithProgram:programObj];
                                          [[AudioManager shared] updateNowPlayingInfoWithAudio:programObj];
                                          [self finishUpdatingForProgram];
                                          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                              UIImage *blurred = [self.programImageView.image blurredImageWithRadius:20.0f
                                                                                                        iterations:3
                                                                                                         tintColor:[UIColor clearColor]];
                                              [[DesignManager shared] setCurrentBlurredLiveImage:blurred];
                                          });
                                          
                                      }];
    } else {
        
        [self updateUIWithProgram:programObj];
        self.view.alpha = 1.0f;
        
    }
    
}

- (void)finishUpdatingForProgram {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.navigationController.navigationBarHidden = NO;
        
        if ( [[UXmanager shared] onboardingEnding] ) {
            [[UXmanager shared] setOnboardingEnding:NO];
        }
        
        [UIView animateWithDuration:0.25 animations:^{
            self.imageTopConstraint.constant = -64.0f;
            [self.view setNeedsUpdateConstraints];
            [self.view layoutIfNeeded];
        }];
        
        [self.liveStreamView layoutIfNeeded];
        [self.initialControlsView layoutIfNeeded];
        [self.liveRewindAltButton layoutIfNeeded];
        [self.queueBlurView setNeedsDisplay];
        [self.programImageView layoutIfNeeded];
        [self setUIContents:YES];
        
        self.view.alpha = 1.0f;
        
        if ( !self.scrubbing ) {
            self.scrubbingUI.view.alpha = 0.0f;
        }
        
        if ( [SCPRCloakViewController cloakInUse] ) {
            [SCPRCloakViewController uncloak];
        }

        
        UIImage *blurry = [self.programImageView.image blurredImageWithRadius:20.0f
                                                                   iterations:3
                                                                    tintColor:[UIColor clearColor]];
        
        
        self.queueBlurView.image = blurry;
        
    });
}

- (void)updateUIWithProgram:(Program*)program {
    
    if ([program title]) {
        if ([program title].length <= 14) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:46.0]];
        } else if ([program title].length > 14 && [program title].length <= 18) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:35.0]];
        } else {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:30.0]];
        }
        [self.programTitleLabel setText:[program title]];
    }
    
    if ( SEQ(program.program_slug,@"kpcc-live") ) {
        [self primeManualControlButton];
    }
    
    [self adjustScrubbingState];
    [self adjustScrollingState];
}

- (void)primePlaybackUI:(BOOL)animated {
    
    if ( self.lockAnimationUI ) return;
    self.lockAnimationUI = YES;
    
    if (animated) {
        
        [UIView animateWithDuration:0.25 animations:^{
            self.initialControlsView.alpha = 0.0f;
            self.letsGoLabel.alpha = 0.0f;
            self.liveStreamView.alpha = 1.0f;
            
            CGFloat programTitleConstant = self.deployedProgramTitleConstant;
            [self.programTitleYConstraint setConstant:programTitleConstant];
            
            [self.liveStreamView layoutIfNeeded];
            if ( !self.preRollViewController.tritonAd ) {
                if ( self.initiateRewind ) {
                    self.playPauseButton.alpha = 0.0f;
                }
            }
            
        } completion:^(BOOL finished) {
            POPSpringAnimation *bottomAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            bottomAnim.toValue = @(0);
            BOOL suppressDivider = NO;
            if ( [Utils isThreePointFive] ) {
                if ( [self.preRollViewController tritonAd] ) {
                    
                    bottomAnim.toValue = @(60.0);
                    suppressDivider = YES;
                    if ( self.menuOpen ) {
                        [self decloakForMenu:YES];
                    }
                    
                    
                } else {
                    bottomAnim.toValue = @(self.threePointFivePlayControlsConstant);
                }
            }
            
            [self.liveDescriptionLabel fadeText:@""];
            
            // Hide or show divider depending on screen size
            self.horizDividerLine.layer.opacity = 0.0f;
            if ( !suppressDivider ) {
                
                self.horizDividerLine.translatesAutoresizingMaskIntoConstraints = NO;
                self.liveStreamView.translatesAutoresizingMaskIntoConstraints = NO;
                
                [self.liveStreamView printDimensionsWithIdentifier:@">>>>>>>>> LIVE STREAM VIEW"];
                
                self.dividerLineLeftAnchor.constant = 5.0f;
                self.dividerLineRightAnchor.constant = -5.0f;
                
                [self.liveStreamView layoutIfNeeded];
                NSLog(@">>>>>>>> Divider Width : %1.1f",self.horizDividerLine.frame.size.width);
                
                self.horizDividerLine.layer.transform = CATransform3DMakeScale(0.025f, 1.0f, 1.0f);
                self.horizDividerLine.layer.opacity = 0.4;
                POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
                scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.025f, 1.0f)];
                scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
            
                [self.horizDividerLine.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
                
            } else {
                
                self.horizDividerLine.layer.transform = CATransform3DMakeScale(1.0f, 1.0f, 1.0f);
                
            }
            
            // Get rid of initial play controls
            POPBasicAnimation *fadeControls = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
            fadeControls.toValue = @(0);
            [fadeControls setCompletionBlock:^(POPAnimation *p, BOOL c) {
                
                [self adjustScrubbingState];
                
                if ( !self.preRollViewController.tritonAd ) {
                    if ( [[UXmanager shared] userHasSeenOnboarding] ) {
                        self.initialPlay = YES;
                        
                        if ( [[UXmanager shared].settings userHasColdStartedAudioOnce] ) {
                            if ( ![[UXmanager shared].settings userHasViewedScheduleOnboarding] ) {
                                self.showLiveHelpScreens = YES;
                            }
                        } else {
                            [[UXmanager shared].settings setUserHasColdStartedAudioOnce:YES];
                            [[UXmanager shared] persist];
                        }
                        
                        if ( self.initiateRewind ) {
                            [self activateRewind:RewindDistanceBeginning];
                        } else {
                            [self playAudio:YES];
                        }
                        
                    } else {
                        [[UXmanager shared] beginAudio];
                    }
                } else {
                    if ( ![[UXmanager shared].settings userHasColdStartedAudioOnce] ) {
                        [[UXmanager shared].settings setUserHasColdStartedAudioOnce:YES];
                        [[UXmanager shared] persist];
                    }
                }
                
                
            }];
            
            [self.initialControlsView.layer pop_addAnimation:fadeControls forKey:@"fadeDownInitialControls"];
            [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];
            
            self.lockAnimationUI = NO;
            
        }];
        
    } else {
        self.initialPlayButton.alpha = 0.0f;
        self.initialControlsView.alpha = 0.0f;
        self.initialPlay = YES;
        [self.playerControlsBottomYConstraint setConstant:0];
        self.lockAnimationUI = NO;
    }
}

- (void)primeManualControlButton {
    
    /*BOOL okToShow = ( [[AudioManager shared] status] == StreamStatusPaused &&
                     [[AudioManager shared] currentAudioMode] != AudioModeOnDemand &&
                     ![self jogging] );*/
    
    BOOL okToShow = YES;

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        NSLog(@"Rewind Button - Hiding because onboarding");
        okToShow = NO;
    }
    if ( self.scrubbing ) {
        if ( okToShow ) {
            NSLog(@"Rewind Button - Hiding because the scrubber is up");
        }
        okToShow = NO;
    }
    if ( [[AudioManager shared] prerollPlaying] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because preroll");
        okToShow = NO;
    }
    if ( [[SessionManager shared] sessionHasNoProgram] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because live stream has no clearly defined program");
        okToShow = NO;
    }
    if ( [[AudioManager shared] status] == StreamStatusStopped && [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because onboarding initial state");
        okToShow = NO;
    }
    if ( [[AudioManager shared] status] == StreamStatusPlaying || [[AudioManager shared] isPlayingAudio] ) {
        
        if ( ![[SessionManager shared] sessionIsBehindLive] ) {
            if ( okToShow )
                NSLog(@"Rewind Button - Hiding because audio is playing");
            okToShow = NO;
        }
        
    }
    if ( [[AudioManager shared] calibrating] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because audio is still calibrating");
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because Audio Mode is onDemand");
        okToShow = NO;
    }
    if ( [[AudioManager shared] dropoutOccurred] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because a dropout has occurred");
        okToShow = NO;
    }
    if ( [self jogging] || [[AudioManager shared] seekWillEffectBuffer] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because of the UI is jogging");
        okToShow = NO;
    }
    if ( [self scrubbing] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because of scrubbing" );
    }
    if ( self.preRollViewController.tritonAd ) {
        if ( self.initialPlay ) {
            if ( okToShow )
                NSLog(@"Rewind Button - Hiding because of a Triton Ad");
            okToShow = NO;
        }
    }
    
    [self.liveRewindAltButton removeTarget:nil
                                    action:nil
                          forControlEvents:UIControlEventAllEvents];
    
    [self.liveRewindAltButton setImageEdgeInsets:UIEdgeInsetsMake(0.0, 0.0, 0.0, 20.0)];
    if ( [[SessionManager shared] sessionIsBehindLive] && [[AudioManager shared] status] != StreamStatusStopped ) {
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_back_to_live_xtra-small.png"]
                                  forState:UIControlStateHighlighted];
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_back_to_live_xtra-small.png"]
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Back to Live"
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Back to Live"
                                  forState:UIControlStateHighlighted];
        [self.liveRewindAltButton addTarget:self
                                     action:@selector(activateFastForward)
                           forControlEvents:UIControlEventTouchUpInside
                                    special:YES];
    } else {
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_live_rewind_xtra-small.png"]
                                  forState:UIControlStateHighlighted];
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_live_rewind_xtra-small.png"]
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Rewind to the start of this show"
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Rewind to the start of this show"
                                  forState:UIControlStateHighlighted];
        
        if ( initialPlay ) {
            [self.liveRewindAltButton addTarget:self
                                         action:@selector(activateRewind:)
                               forControlEvents:UIControlEventTouchUpInside
                                        special:YES];
        } else {
            [self.liveRewindAltButton addTarget:self
                                         action:@selector(specialRewind)
                               forControlEvents:UIControlEventTouchUpInside
                                        special:YES];
        }
    }
    


    if ( [[SessionManager shared] sessionIsInRecess:NO] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because we're in no-mans-land");
        okToShow = NO;
    }
    
    
    if ( [[UXmanager shared] onboardingEnding] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because onboarding is ending");
        okToShow = NO;
    }
    if ( [[NetworkManager shared] networkDown] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because program is nil");
        okToShow = NO;
    }
    
    if ( okToShow ) {
        self.onboardingRewindButtonShown = YES;
        self.liveRewindAltButton.userInteractionEnabled = YES;
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 1.0f;
        }];
    } else {
        self.liveRewindAltButton.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 0.0f;
        }];
    }
    
}

- (void)lockUI:(NSNotification*)note {
    
#ifdef DISABLE_INTERRUPT
    return;
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(unlockUI:)
                                                 name:@"network-status-good"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"network-status-fail"
                                                  object:nil];
    
    [self decloakForMenu:YES];
    if ( self.preRollOpen ) {
        [self decloakForPreRoll:NO];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        self.onDemandPlayerView.alpha = 0.45;
        self.onDemandPlayerView.userInteractionEnabled = NO;
        self.timeLabelOnDemand.alpha = 0.0f;
    }
    
    if ( self.initialPlay ) {
        if ( [[NetworkManager shared] audioWillBeInterrupted] ) {
            //[[AudioManager shared] pauseAudio];
        }
    } else {
        if ( !self.menuOpen ) {
            self.initialPlayButton.alpha = 0.4;
        }
        self.initialControlsView.userInteractionEnabled = NO;
    }
    
    if ( !self.menuOpen ) {
        self.playerControlsView.alpha = 0.45;
    }
    self.playerControlsView.userInteractionEnabled = NO;
    [self.liveProgressViewController hide];
    self.programTitleLabel.alpha = 0.4;
    
    self.liveDescriptionLabel.text = @"NO NETWORK";
    [self.liveProgressViewController hide];
    
    if ( note && !self.promptedAboutFailureAlready ) {
        self.promptedAboutFailureAlready = YES;
    }
    
    [self determinePlayState];

    
}

- (void)unlockUI:(NSNotification*)note {
    
#ifdef DISABLE_INTERRUPT
    return;
#endif
    
    NSLog(@" ||||||||||| UNLOCKING UI FROM NETWORK GAP |||||||||||| ");
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockUI:)
                                                 name:@"network-status-fail"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"network-status-good"
                                                  object:nil];
    
    self.dirtyFromFailure = YES;
    self.promptedAboutFailureAlready = NO;
    self.preRollViewController.tritonAd = nil;
    self.initialPlayButton.alpha = 1.0f;
    self.initialPlayButton.userInteractionEnabled = YES;
    
    if ( self.preRollOpen ) {
        [self decloakForPreRoll:NO];
    }
    

    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnDemand ) {
        [self updateDataForUI];
        [self determinePlayState];
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        self.onDemandPlayerView.alpha = 1.0f;
        self.timeLabelOnDemand.alpha = 1.0f;
    }
    
    if ( !self.menuOpen ) {
        if ( self.initialPlay ) {
            self.playerControlsView.alpha = 1.0f;
            self.programTitleLabel.alpha = 1.0f;
            [self.liveProgressViewController show];
        } else {
            self.initialControlsView.alpha = 1.0f;
            self.playerControlsView.alpha = 1.0f;
            self.initialPlayButton.alpha = 1.0f;
            self.initialPlayButton.userInteractionEnabled = YES;
        }
    }
    
    self.onDemandPlayerView.userInteractionEnabled = YES;
    self.playerControlsView.userInteractionEnabled = YES;
    self.initialControlsView.userInteractionEnabled = YES;
    self.playerControlsView.userInteractionEnabled = YES;
    
    self.liveStreamView.alpha = 1.0f;
    self.liveStreamView.userInteractionEnabled = YES;
    self.programTitleLabel.alpha = 1.0f;
    
}

- (void)pushToHiddenVector:(UIView *)viewToHide {
    if ( self.hiddenVectorCommitted ) return;
    
    if ( viewToHide.alpha > 0.0f ) {
        [self.hiddenVector addObject:@{ @"view" : viewToHide, @"alpha" : @(viewToHide.alpha) }];
    }
}

- (void)commitHiddenVector {
    
    if ( self.hiddenVectorCommitted ) return;
    
    [UIView animateWithDuration:0.1f animations:^{
        for ( NSDictionary *th in self.hiddenVector ) {
            UIView *v2h = th[@"view"];
            v2h.alpha = 0.0f;
        }
    } completion:^(BOOL finished) {
        self.hiddenVectorCommitted = YES;
    }];
}

- (void)popHiddenVector {
    
    if ( !self.hiddenVectorCommitted ) return;
    
    [UIView animateWithDuration:0.1f animations:^{
        for ( NSDictionary *th in self.hiddenVector ) {
            UIView *v2h = th[@"view"];
            v2h.alpha = [th[@"alpha"] floatValue];
        }
    } completion:^(BOOL finished) {
        [self.hiddenVector removeAllObjects];
        self.hiddenVectorCommitted = NO;
    }];
}

- (void)mutePrimaryControls {
    
    if ( self.hiddenVectorCommitted ) return;
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = del.masterNavigationController;
    self.scrubbingTriggerView.userInteractionEnabled = NO;
    
    [self pushToHiddenVector:self.playerControlsView];
    [self pushToHiddenVector:self.initialControlsView];
    [self pushToHiddenVector:self.scrubbingTriggerView];
    [self pushToHiddenVector:nav.menuButton];
    [self pushToHiddenVector:self.liveRewindAltButton];
    [self pushToHiddenVector:[[[Utils del] xfsInterface] view]];
    
    [self commitHiddenVector];
    
}

- (void)unmutePrimaryControls {
    
    if ( !self.hiddenVectorCommitted ) return;
    
    self.scrubbingTriggerView.userInteractionEnabled = YES;
    [self popHiddenVector];
}

- (void)adjustScrollingState {
    
    self.mainContentScroller.scrollEnabled = YES;
    if ( self.menuOpen ) {
        self.mainContentScroller.scrollEnabled = NO;
    }
    if ( self.preRollOpen ) {
        self.mainContentScroller.scrollEnabled = NO;
    }
    if ( !self.initialPlay ) {
        self.mainContentScroller.scrollEnabled = NO;
    }
    if ( [[SessionManager shared] sessionHasNoProgram] ) {
        self.mainContentScroller.scrollEnabled = NO;
    }
    if ( [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
        self.mainContentScroller.scrollEnabled = NO;
    }
    
}

- (void)adjustScrubbingState {
    
    BOOL back30 = YES;
    BOOL fwd30 = YES;
    BOOL scrubbing = YES;
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeLive &&
        [[AudioManager shared] currentAudioMode] != AudioModeOnDemand ) {
        back30 = NO;
        fwd30 = NO;
        scrubbing = NO;
    }
    if ( [[SessionManager shared] sessionHasNoProgram] ) {
        back30 = NO;
        fwd30 = NO;
        scrubbing = NO;
    }
    if ( ![[SessionManager shared] sessionIsBehindLive] ) {
        fwd30 = NO;
    }
    if ( self.scrubbing ) {
        scrubbing = NO;
    }
    if ( self.mainContentScroller.contentOffset.x > 0.0f ) {
        scrubbing = NO;
    }
    if ( self.menuOpen || self.preRollOpen ) {
        fwd30 = NO;
        back30 = NO;
        scrubbing = NO;
    }
    
    [self animatedStateForBackwardButton:back30];
    [self animatedStateForForwardButton:fwd30];
    self.scrubbingTriggerView.alpha = scrubbing ? 1.0f : 0.0f;
    
          
}

#pragma mark - XFS
- (void)cloakForXFS {
    self.pulldownMenu.alpha = 1.0f;
    
    [self dismissXFSCoachingBalloon];
    
    [self pushToHiddenVector:self.mainContentScroller];
    [self pushToHiddenVector:self.initialControlsView];
    [self pushToHiddenVector:self.playerControlsView];
    [self pushToHiddenVector:self.liveProgressViewController.view];
    
    [[UXmanager shared] hideMenuButton];
    
    [self.pulldownMenu primeWithType:MenuTypeXFS];
    [self.pulldownMenu setDelegate:[[Utils del] xfsInterface]];
    [self.pulldownMenu openDropDown:YES];
    
    [UIView animateWithDuration:0.33f animations:^{
        self.queueBlurView.alpha = 1.0f;
        self.queueDarkBgView.alpha = 0.4f;
    } completion:^(BOOL finished) {
        self.streamSelectorOpen = YES;
    }];
    
    [self commitHiddenVector];
}

- (void)decloakForXFS {
    
    [self popHiddenVector];
    [self.pulldownMenu closeDropDown:YES];
    
    [UIView animateWithDuration:0.33f animations:^{
        self.queueBlurView.alpha = 0.0f;
        self.queueDarkBgView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        
        [[UXmanager shared] showMenuButton];
        
        [self.pulldownMenu primeWithType:MenuTypeStandard];
        [self.pulldownMenu setDelegate:self];
        
        self.streamSelectorOpen = NO;
        self.pulldownMenu.alpha = 0.0f;
    }];
}

- (void)xfsHidden {
    [self decloakForXFS];
    
    /*[[AnalyticsManager shared] logEvent:@"stream-selector-closed"
                         withParameters:nil];*/
}

- (void)xfsShown {
    [self cloakForXFS];
    
    /*[[AnalyticsManager shared] logEvent:@"stream-selector-opened"
                         withParameters:nil];*/
    
}

- (void)xfsToggle {
    self.navigationItem.title = kMainLiveStreamTitle;
}

- (void)showBalloonWithText:(NSString *)text {
    [[Utils del] showCoachingBalloonWithText:text];
}

- (void)dismissXFSCoachingBalloon {
    SCPRXFSViewController *xfsvc = [[Utils del] xfsInterface];
    [xfsvc dismissCoachingBalloon];
}

- (void)xfsConfirm {
    
    [[[Utils del] xfsInterface] grayInterface];
    
    SCPRPledgePINViewController *pin = [[SCPRPledgePINViewController alloc]
                                        initWithNibName:@"SCPRPledgePINViewController"
                                        bundle:nil];
    pin.view = pin.view;
    pin.parentXFSViewController = [[Utils del] xfsInterface];
    
    [self.navigationController pushViewController:pin
                                         animated:YES];
    
}

- (void)xfsExit {
    self.navigationItem.title = kMainLiveStreamTitle;
    [self.navigationController popViewControllerAnimated:YES];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent
                                                animated:YES];
    
    [self.pulldownMenu.menuList reloadData];
    
    if ( [[SessionManager shared] userIsSwitchingToKPCCPlus] ) {
        [[SessionManager shared] setUserIsSwitchingToKPCCPlus:NO];
        if ( [[AudioManager shared] isActiveForAudioMode:AudioModeLive] ) {
            [[AudioManager shared] switchPlusMinusStreams];
        } else {
            [self goLive:YES];
        }
    }
}

- (void)xfsAvailability {

    BOOL available = [[SessionManager shared] xFreeStreamIsAvailable];
    if ( !available ) {
        
        BOOL xfs = [[UXmanager shared].settings userHasSelectedXFS];
        [[UXmanager shared].settings setUserHasSelectedXFS:NO];
        [[UXmanager shared].settings setXfsToken:nil];
        [[UXmanager shared] persist];
        
        if ( xfs ) {
            [self showBalloonWithText:@"KPCC Plus will return for the next pledge drive. Thanks for your support as a member!"];
            [[AudioManager shared] switchPlusMinusStreams];
            [[[Utils del] xfsInterface] partialRemoval];
        } else {
            [[Utils del] controlXFSAvailability:available];
        }
        
    } else {
        if ( ![[UXmanager shared].settings userHasViewedXFSOnboarding] ) {
            [self showBalloonWithText:@"It's pledge-drive time! KPCC members can tap here to access KPCC Plus."];
        }
        [[Utils del] controlXFSAvailability:available];
    }
 
}

#pragma mark - Util

- (BOOL)cloaked {
    return (self.scrubbing || self.preRollOpen || self.menuOpen || self.streamSelectorOpen );
}


#pragma mark - Menu control
- (void)cloakForMenu:(BOOL)animated {
    [self cloakForMenu:animated
      suppressDropdown:NO];
}

- (void)cloakForMenu:(BOOL)animated suppressDropdown:(BOOL)suppressDropdown {
    
    if ( [AudioManager shared].currentAudioMode == AudioModePreroll ) return;
    
    self.menuOpen = YES;
    
    [self removeAllAnimations];
    
    self.pulldownMenu.alpha = 1.0f;
    [self.liveProgressViewController hide];
    
    [self dismissXFSCoachingBalloon];
    
    self.navigationItem.title = @"Menu";
    
    if ( !suppressDropdown ) {
        [pulldownMenu openDropDown:animated];
    }
  
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @0;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeAnimation"];
    }
    
    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @1.0f;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *lsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    lsFade.toValue = @(0);
    lsFade.duration = 0.3;
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    } else {
        [self.queueBlurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    }
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:lsFade forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"initialControlsViewFade"];
    }
    
    [self pushToHiddenVector:self.liveRewindAltButton];
    [[Utils del] controlXFSAvailability:[[SessionManager shared] xFreeStreamIsAvailable]];
    [self pushToHiddenVector:[[[Utils del] xfsInterface] view]];
    [self pushToHiddenVector:self.shareButton];
    [self commitHiddenVector];
    
    POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    dividerFadeAnim.toValue = @0;
    dividerFadeAnim.duration = 0.3;
    [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerOutFadeAnimation"];
    
    
    [self adjustScrubbingState];
    [self adjustScrollingState];
    
}

- (void)decloakForMenu:(BOOL)animated {
    
    if ( [AudioManager shared].currentAudioMode == AudioModePreroll ) return;
    
    if ( !self.menuOpen ) return;
    
    self.menuOpen = NO;
    
    [self removeAllAnimations];
    
    if (setForOnDemandUI) {
        self.navigationItem.title = @"Programs";
    } else {
        self.navigationItem.title = kMainLiveStreamTitle;
    }
    

    [pulldownMenu closeDropDown:animated];
    
    
    NSNumber *restoredAlpha = [[NetworkManager shared] networkDown] ? @.45f : @1;
    
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = restoredAlpha;
        onDemandElementsFade.duration = 0.3f;
        self.shareButton.alpha = 1.0f;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeInAnimation"];
    }
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3f;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.0f;
    darkBgFadeAnimation.duration = 0.3f;
    
    POPBasicAnimation *controlsFadeIn = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeIn.toValue = @1.0f;
    controlsFadeIn.duration = 0.3f;
    
    POPBasicAnimation *cfi = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    cfi.toValue = restoredAlpha;
    cfi.duration = 0.3f;
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    } else {
        if ( ![[DesignManager shared] protectBlurredImage] ) {
            [self.queueBlurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
        }
    }
    
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeIn forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeIn forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:cfi forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeIn forKey:@"initialControlsViewFade"];
    }
    
    //if (setForOnDemandUI) {
    if ( self.initialPlay || setForOnDemandUI ) {
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4f;
        dividerFadeAnim.duration = 0.3f;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
    }
    //}
    if ( [AudioManager shared].currentAudioMode == AudioModeLive && !setForOnDemandUI ) {
        [self.liveProgressViewController show];
    } else {
        [self.liveProgressViewController hide];
    }
    
    if ( [[NetworkManager shared] networkDown] ) {
        self.initialPlayButton.alpha = 0.4f;
        self.playPauseButton.alpha = 0.4f;
    }
    
    [self popHiddenVector];
    
    if ( !self.homeIsNotRootViewController ) {
        [[Utils del] controlXFSAvailability:[[SessionManager shared] virtualLiveAudioMode]];
    } else {
        [[Utils del] controlXFSAvailability:NO];
    }
    
    [self adjustScrollingState];
    [self adjustScrubbingState];
    
    
}

- (void)removeAllAnimations {
    [self.queueBlurView.layer pop_removeAllAnimations];
    [self.darkBgView.layer pop_removeAllAnimations];
    [self.playerControlsView.layer pop_removeAllAnimations];
    [self.onDemandPlayerView.layer pop_removeAllAnimations];
    [self.liveStreamView.layer pop_removeAllAnimations];
    [self.horizDividerLine.layer pop_removeAllAnimations];
    [self.timeLabelOnDemand.layer pop_removeAllAnimations];
    [self.progressView.layer pop_removeAllAnimations];
    [self.queueScrollView.layer pop_removeAllAnimations];
}


# pragma mark - PreRoll Control

- (void)cloakForPreRoll:(BOOL)animated {
    
    self.preRollOpen = YES;
    [[AudioManager shared] setCurrentAudioMode:AudioModePreroll];
    [[UXmanager shared] hideMenuButton];
    
    [self removeAllAnimations];
    
    [self dismissXFSCoachingBalloon];
    
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @0;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
    } else {
        [self.liveProgressViewController hide];
    }
    
    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.0f;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;
    
    
    [self.queueBlurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    //[self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];
    [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsFade"];
    [self.programTitleLabel.layer pop_addAnimation:controlsFadeAnimation forKey:@"titleFade"];
    [self.liveDescriptionLabel.layer pop_addAnimation:controlsFadeAnimation forKey:@"statusFade"];
    
    [self pushToHiddenVector:[[[Utils del] xfsInterface] view]];
    [self commitHiddenVector];
    
    [self adjustScrollingState];
    [self adjustScrubbingState];
    
    [self.view bringSubviewToFront:self.playerControlsView];
    
}

- (void)decloakForPreRoll:(BOOL)animated {
    [self removeAllAnimations];
    
    self.preRollOpen = NO;
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @1;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
    }
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @1;
    controlsFadeAnimation.duration = 0.3;
    
    [self.queueBlurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    //[self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];
    [self.programTitleLabel.layer pop_addAnimation:controlsFadeAnimation forKey:@"titleFadeUp"];
    [self.liveDescriptionLabel.layer pop_addAnimation:controlsFadeAnimation forKey:@"statusFadeUp"];
    
    if ([[AudioManager shared] isStreamPlaying]) {
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
    }
    
    [self popHiddenVector];
    
    [self adjustScrubbingState];
    [self adjustScrollingState];
    
    
}

# pragma mark - SCPRPreRollControllerDelegate
- (void)preRollStartedPlaying {
    [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
}

- (void)preRollCompleted {

    [self.preRollViewController removeFromParentViewController];
    [self.preRollViewController.view removeFromSuperview];
    self.preRollViewController.tritonAd = nil;
    
    self.initialPlay = YES;
    
    if ( [Utils isThreePointFive] ) {
        POPSpringAnimation *bottomAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
        bottomAnim.toValue = @(self.threePointFivePlayControlsConstant);
        [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];
        self.horizDividerLine.layer.opacity = 0.4;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.preRollOpen) {
            [self decloakForPreRoll:YES];
        }
        
        if ( self.initiateRewind ) {
            [self activateRewind:RewindDistanceBeginning];
        } else {
            [self playAudio:YES];
        }
    });
    
}


#pragma mark - UIScrollViewDelegate for audio queue
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    if ( scrollView == self.queueScrollView ) {
        NSLog(@"Will begin dragging ... ");
        self.onDemandPanning = YES;
        [self onDemandFadeDown];
    }
    if ( scrollView == self.mainContentScroller ) {
        
        if ( self.mainContentScroller.contentOffset.x == 0.0f ) {
            
            self.dividerLineRightAnchor.constant = 0.0f;
            self.dividerLineLeftAnchor.constant = 0.0f;
            if ( ![Utils isIOS8] ) {
                [self.upcomingScreen alignDividerToValue:0.0f];
            }
            [UIView animateWithDuration:0.25f animations:^{
                
                [self.liveStreamView layoutIfNeeded];
                self.queueBlurView.alpha = 1.0f;
                self.queueDarkBgView.alpha = 0.4f;
                
                [self mutePrimaryControls];
                
            }];
            
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    if ( scrollView == self.queueScrollView ) {
        int newPage = scrollView.contentOffset.x / scrollView.frame.size.width;
        if (self.queueCurrentPage == newPage) {
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.timeLabelOnDemand.alpha = 1.0f;
                self.progressView.alpha = 1.0f;
                self.queueBlurView.alpha = 0.0f;
                self.queueDarkBgView.alpha = 0.0f;
                self.shareButton.alpha = 1.0f;
            } completion:^(BOOL finished) {
                self.queueBlurShown = NO;
            }];
            return;
        }
        
        if (self.queueScrollTimer != nil && [self.queueScrollTimer isValid]) {
            [self.queueScrollTimer invalidate];
            self.queueScrollTimer = nil;
        }
        
        if ( [[AudioManager shared] status] == StreamStatusPlaying ) {
            if ( ![self.jogShuttle spinning] ) {
                [self snapJogWheel];
            }
        }
        
        self.queueScrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                 target:self
                                                               selector:@selector(queueScrollEnded)
                                                               userInfo:nil
                                                                repeats:NO];
    }
    if ( scrollView == self.mainContentScroller ) {
      
        NSLog(@"***** Scroll View Did End Decelerating *****");
        [UIView animateWithDuration:0.18f animations:^{
            if ( self.mainContentScroller.contentOffset.x == 0.0f ) {
                self.queueBlurView.alpha = 0.0f;
                self.queueDarkBgView.alpha = 0.0f;
                self.dividerLineRightAnchor.constant = -5.0f;
                self.dividerLineLeftAnchor.constant = 5.0f;
                [self.liveStreamView layoutIfNeeded];
                [self unmutePrimaryControls];
            } else {
                [self trackSchedulingSwipes];
                [self mutePrimaryControls];
            }
            
            
        }];
        
    }
}


- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    NSLog(@"***** Scroll View Did End Dragging *****");
    if ( scrollView == self.mainContentScroller ) {
        [UIView animateWithDuration:0.18f animations:^{
            if ( self.mainContentScroller.contentOffset.x == 0.0f ) {
                self.queueBlurView.alpha = 0.0f;
                self.queueDarkBgView.alpha = 0.0f;
                self.dividerLineRightAnchor.constant = -5.0f;
                self.dividerLineLeftAnchor.constant = 5.0f;
                [self.liveStreamView layoutIfNeeded];
                [self unmutePrimaryControls];
            } else {
                [self trackSchedulingSwipes];
                [self mutePrimaryControls];
            }
        }];
    }
}

- (void)trackSchedulingSwipes {
    NSString *event = nil;
    NSInteger index = floorf((float)(self.mainContentScroller.contentOffset.x / self.mainContentScroller.frame.size.width));
    if ( index == 2 ) {
        event = @"userViewingFullSchedule";
    } else if ( index == 1 ) {
        event = @"userViewingUpNext";
    }
    
    if ( event ) {
        [[AnalyticsManager shared] logEvent:event withParameters:@{}];
    }
}

#pragma mark - On demand loading transitions
- (void)onDemandFadeDown {
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        //self.timeLabelOnDemand.alpha = 0.0f;
        self.progressView.alpha = 0.0f;
        self.shareButton.alpha = 0.0f;
    } completion:^(BOOL finished){
        
    }];
    
    if (!self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            self.queueBlurView.alpha = 1.0f;
            self.queueDarkBgView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.queueBlurShown = YES;
        }];
    }
}

- (void)queueScrollEnded {
    
    [[AudioManager shared] invalidateTimeObserver];
    
    self.onDemandPanning = NO;
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.timeLabelOnDemand.alpha = 1.0f;
    } completion:nil];
    
    
    
    int newPage = self.queueScrollView.contentOffset.x / self.queueScrollView.frame.size.width;
    if ((self.queueContents)[newPage]) {
        AudioChunk *chunk = (self.queueContents)[newPage];
        self.onDemandEpUrl = chunk.contentShareUrl;
        [[AudioManager shared] updateNowPlayingInfoWithAudio:chunk];
    }
    
    if (self.queueCurrentPage != newPage) {
        
        [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
            self.playPauseButton.enabled = YES;
            [self updateControlsAndUI:YES];
        }];
        
        self.timeLabelOnDemand.text = @"LOADING...";
        self.queueLoading = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            double progress = [[QueueManager shared] globalProgress];
            
            if ( progress <= .15 ) {
                [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeSkipped];
            }
            
            [[QueueManager shared] playItemAtPosition:newPage];
            self.queueCurrentPage = newPage;
            
        });
        
        
    } else {
        [self.jogShuttle endAnimations];
        [self rebootOnDemandUI];
    }
}

- (void)rebootOnDemandUI {
    
    if (self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            
            self.queueBlurView.alpha = 0.0f;
            self.queueDarkBgView.alpha = 0.0f;
            self.progressView.alpha = 1.0f;
            self.shareButton.alpha = 1.0f;
            self.timeLabelOnDemand.alpha = 1.0f;
            SCPRQueueScrollableView *cv = self.queueUIContents[self.queueCurrentPage];
            if ( self.scrubbing ) {
                cv.audioTitleLabel.alpha = 0.6;
            }
            
        } completion:^(BOOL finished) {
            self.queueBlurShown = NO;
            [self.jogShuttle endAnimations];
        }];
        
    } else {
        [self.jogShuttle endAnimations];
    }
    
    self.playPauseButton.userInteractionEnabled = YES;
}

# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    
    BOOL closeMenu = NO;
    NSString *event = @"";
    switch (indexPath.row) {
        case 0:
        {
            event = @"menuSelectionLiveStream";
            closeMenu = YES;
            if ( [AudioManager shared].currentAudioMode != AudioModeLive ) {
                [self goLive:YES];
            }
            break;
        }
            
        case 1:
        {
            
            self.homeIsNotRootViewController = YES;
            event = @"menuSelectionPrograms";
            Program *prog = [[SessionManager shared] currentProgram];
            if (setForOnDemandUI && self.onDemandProgram != nil) {
                prog = self.onDemandProgram;
            }
            
            [[DesignManager shared] setProtectBlurredImage:YES];
            SCPRProgramsListViewController *vc = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:prog];
            [self.navigationController pushViewController:vc animated:YES];
            
            break;
        }
            
        case 2: {
            
            self.homeIsNotRootViewController = YES;
            event = @"menuSelectionHeadlines";
            SCPRShortListViewController *slVC = [[SCPRShortListViewController alloc] initWithNibName:@"SCPRShortListViewController"
                                                                                              bundle:nil];
            slVC.view = slVC.view;
            [self.navigationController pushViewController:slVC animated:YES];
            break;
            
        }
        case 3: {
            
            self.homeIsNotRootViewController = YES;
            closeMenu = YES;
            
            event = @"menuSelectionWakeSleep";
            SCPRTimerControlViewController *timer = [[SCPRTimerControlViewController alloc] initWithNibName:@"SCPRTimerControlViewController"
                                                                                                     bundle:nil];
            
            CGSize bounds = [[UIScreen mainScreen] bounds].size;
            timer.view.frame = CGRectMake(0.0,0.0,bounds.width,bounds.height);
            
            [self.navigationController pushViewController:timer
                                                 animated:YES];
            
            [timer setup];
            
            self.restoreTitle = YES;
            
            break;
        }
        case 4: {
            event = @"menuSelectionDonate";
            
            [[AnalyticsManager shared] logEvent:@"userSelectedDonate"
                                 withParameters:nil];
            
            NSString *urlStr = @"https://scprcontribute.publicradio.org/contribute.php?refId=iphone&askAmount=60";
            NSURL *url = [NSURL URLWithString:urlStr];
            closeMenu = YES;
            [[UIApplication sharedApplication] openURL:url];
            break;
        }
        /*case 5: {
            
            if ( [[UXmanager shared] userLoginType] == SSOTypeNone ) {
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(pushToProfile)
                                                             name:@"tokens-stored"
                                                           object:nil];
                
                SCPRLoginViewController *login = [[SCPRLoginViewController alloc] initWithNibName:@"SCPRLoginViewController"
                                                                                           bundle:nil];
                login.view.frame = CGRectMake(0.0f,0.0f,self.view.frame.size.width,
                                              self.view.frame.size.height);
                
                [self presentViewController:login
                                   animated:YES
                                 completion:^{
                                     self.userIsLoggingIn = YES;
                                     [login.view layoutIfNeeded];
                                 }];
                
            } else {
                [self pushToProfile];
            }
            break;
        }*/
        case 5: {
            
            self.homeIsNotRootViewController = YES;
            event = @"menuSelectionFeedback";
            SCPRFeedbackViewController *fbVC = [[SCPRFeedbackViewController alloc] initWithNibName:@"SCPRFeedbackViewController"
                                                                                            bundle:nil];
            [self.navigationController pushViewController:fbVC animated:YES];
            
            break;
            
        }
        default: {
            closeMenu = YES;
            break;
        }
    }
    
    /*[[AnalyticsManager shared] logEvent:event
                         withParameters:@{}];*/
    
    if ( closeMenu ) {
        [self decloakForMenu:YES];
    }
}

- (void)pushToProfile {

    if ( [[UXmanager shared].settings ssoLoginType] != SSOTypeNone ) {
        
        if ( self.userIsLoggingIn ) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:@"tokens-stored"
                                                          object:nil];
            [self dismissViewControllerAnimated:YES completion:^{
                SCPRProfileViewController *profile = [[SCPRProfileViewController alloc] initWithNibName:@"SCPRProfileViewController"
                                                                                             bundle:nil];
                self.userIsLoggingIn = NO;
                
                profile.view = profile.view;
                [profile setup];
                
                [self.navigationController pushViewController:profile animated:YES];
            }];
        } else {
            SCPRProfileViewController *profile = [[SCPRProfileViewController alloc] initWithNibName:@"SCPRProfileViewController"
                                                                                             bundle:nil];
            
            profile.view = profile.view;
            [profile setup];
            
            [self.navigationController pushViewController:profile animated:YES];
        }

    }
}

- (void)pullDownAnimated:(BOOL)open {
    // Notifications used in SCPRNavigationController.
    if (open) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
    }
}


# pragma mark - AudioManagerDelegate

- (void)onRateChange {
    
    self.playStateGate = YES;
    if ( !self.initiateRewind || self.preRollViewController.tritonAd ) {
        [self.liveProgressViewController setFreezeBit:YES];
        [self updateControlsAndUI:YES];
    }
    
}

- (void)onTimeChange {
    
    if ( self.jogging ) {
        return;
    }
    
    NSAssert([NSThread isMainThread],@"This is not the main thread...");
    
    if ( [[AudioManager shared] frameCount] % 10 == 0 ) {
        if ( !self.menuOpen ) {
            [self prettifyBehindLiveStatus];
        }
        

        if ( self.showLiveHelpScreens ) {
            self.showLiveHelpScreens = NO;
            SCPRAppDelegate *del = [Utils del];
            [del onboardForLiveFunctionality];
        }
        
        [self adjustScrollingState];
        
        if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
            if ( self.liveRewindAltButton.alpha == 1.0 || self.liveRewindAltButton.layer.opacity == 1.0 )
                [self primeManualControlButton];
            
            if ( !self.menuOpen ) {
                if ( self.liveStreamView.layer.opacity < 1.0 ) {
                    [UIView animateWithDuration:0.25 animations:^{
                        NSLog(@"Opacity was affected");
                        self.liveStreamView.layer.opacity = 1.0f;
                    }];
                    

                }
                
            }
        }
        
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self.progressView pop_removeAllAnimations];
        } else {
            if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ||
                [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
                if ( !self.menuOpen && ![[UXmanager shared] notificationsPromptDisplaying] ) {
                    if ( !self.preRollOpen ) {
                        if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
                            if ( ![[UXmanager shared] notificationsPromptDisplaying] ) {
                                [self.liveProgressViewController show];
                            }
                        } else {
                            if ( self.initialPlay ) {
                                [self.liveProgressViewController show:YES];
                            }
                        }
                    }
                }
            }
        }
        
        [[AnalyticsManager shared] nielsenTrack];
        
    }
    
    [self.liveProgressViewController tick];
    [self tickOnDemand];
    
}



- (void)tickOnDemand {
 
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnDemand )
        return;
    
    if ( !self.onDemandPanning )
        [self rebootOnDemandUI];
    
    if (CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]) > 0) {
        double currentTime = CMTimeGetSeconds([[[AudioManager shared].audioPlayer currentItem] currentTime]);
        double duration = CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]);
        double progress = (currentTime / duration);
        
        [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:currentTime
                                                                 andDuration:duration]];
        
        [[AnalyticsManager shared] trackEpisodeProgress:progress];
        [[QueueManager shared] setGlobalProgress:progress];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView setProgress:progress animated:YES];
        });
        
        
    }
    [[QueueManager shared] handleBookmarkingActivity];
    
}

- (void)onSeekCompleted {
    // Make sure UI gets set to "Playing" state after a seek.
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self.jogShuttle endAnimations];
    }];
}

- (void)onDemandSeekCompleted {
    [self.jogShuttle endAnimations];
}

- (void)interfere {
    [self.liveDescriptionLabel stopPulsating];
    self.jogging = YES;
    [self.liveDescriptionLabel fadeText:@"BUFFERING..."];
}

- (void)onDemandAudioFailed {
    self.timeLabelOnDemand.text = @"FAILED TO LOAD";
    self.onDemandFailing = YES;
    
    if ( ![[QueueManager shared]isQueueEmpty] ) {
        if ( self.queueCurrentPage < [self.queueContents count]-1 ) {
            [[QueueManager shared] playNext];
        } else {
            [self warnUserOfOnDemandFailures];
            [self goLive:YES];
        }
    } else {
        [self warnUserOfOnDemandFailures];
        [self goLive:YES];
    }
    
}

- (void)warnUserOfOnDemandFailures {
    [[[UIAlertView alloc] initWithTitle:@"That show is unavailable"
                                message:@"Unfortunately there seems to be some trouble loading episodes from that program. Please try again later. In the meantime, please enjoy the live stream from KPCC"
                               delegate:nil
                      cancelButtonTitle:@"Got It"
                      otherButtonTitles:nil] show];
}

- (void)restoreUIIfNeeded {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-good"
                                                        object:nil];
}

#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    /*    if ([content count] == 0) {
     return;
     }
     
     // Create Program and insert into managed object context
     if ([content objectAtIndex:0]) {
     NSDictionary *programDict = [content objectAtIndex:0];
     
     Program *programObj = [Program insertProgramWithDictionary:programDict inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
     
     // Only update background image when we're not in On Demand mode.
     if (!setForOnDemandUI){
     [[DesignManager shared] loadProgramImage:programObj.program_slug
     andImageView:self.programImageView
     completion:^(BOOL status) {
     [self.blurView setNeedsDisplay];
     [self.queueBlurView setNeedsDisplay];
     }];
     }
     
     [self updateUIWithProgram:programObj];
     
     if (!setForOnDemandUI) {
     [[AudioManager shared] updateNowPlayingInfoWithAudio:programObj];
     }
     
     self.currentProgram = programObj;
     
     // Save any programObj changes to CoreData.
     [[ContentManager shared] saveContext];
     }
     */
}

- (void)dealloc {
    //End receiving events.
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)primeRemoteCommandCenter:(BOOL)forLiveStream {
    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];
    
    if (forLiveStream) {
        [[rcc previousTrackCommand] setEnabled:NO];
        MPSkipIntervalCommand *skipBackwardIntervalCommand = [rcc skipBackwardCommand];
        [skipBackwardIntervalCommand setEnabled:YES];
        [skipBackwardIntervalCommand addTarget:self action:@selector(skipBackwardEvent:)];
        skipBackwardIntervalCommand.preferredIntervals = @[@(15)];
        
        [[rcc nextTrackCommand] setEnabled:NO];
        MPSkipIntervalCommand *skipForwardIntervalCommand = [rcc skipForwardCommand];
        skipForwardIntervalCommand.preferredIntervals = @[@(15)];  // Max 99
        [skipForwardIntervalCommand setEnabled:YES];
        [skipForwardIntervalCommand addTarget:self action:@selector(skipForwardEvent:)];
    } else {
        [[rcc skipBackwardCommand] setEnabled:NO];
        MPRemoteCommand *prevTrackCommand = [rcc previousTrackCommand];
        [prevTrackCommand addTarget:self action:@selector(prevEpisodeTapped:)];
        [prevTrackCommand setEnabled:YES];
        
        [[rcc skipForwardCommand] setEnabled:NO];
        MPRemoteCommand *nextTrackCommand = [rcc nextTrackCommand];
        [nextTrackCommand addTarget:self action:@selector(nextEpisodeTapped:)];
        [nextTrackCommand setEnabled:YES];
    }
    
    MPRemoteCommand *pauseCommand = [rcc pauseCommand];
    [pauseCommand setEnabled:YES];
    [pauseCommand addTarget:self action:@selector(pauseTapped:)];
    
    MPRemoteCommand *playCommand = [rcc playCommand];
    [playCommand setEnabled:YES];
    [playCommand addTarget:self action:@selector(playTapped:)];
}

#pragma mark - UIAlertView
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    if ( alertView.tag == kCancelSleepTimerAlertTag ) {
        if ( buttonIndex == 1 ) {
            [[SessionManager shared] cancelSleepTimerWithCompletion:nil];
        }
        return;
    }
    
    self.promptedAboutFailureAlready = NO;
    if ( buttonIndex == 0 ) {
        self.uiLocked = NO;
        [self updateDataForUI];
    }
    
}

#pragma mark - Compose Mail
- (void)composeMail:(NSNotification *)note {
    
    if ( self.mailCompositionDisplaying ) return;
    
    if ( [MFMailComposeViewController canSendMail] ) {
        self.mailCompositionDisplaying = YES;
        self.mComposer = [[MFMailComposeViewController alloc] init];
        MFMailComposeViewController *compose = self.mComposer;
        
        NSDictionary *ui = [note userInfo];
        if ( ui[@"subject"] ) {
            [compose setSubject:ui[@"subject"]];
        }
        
        NSString *body = ui[@"body"];
        if ( body ) {
            if ( ui[@"subtext"] ) {
                NSDictionary *st = ui[@"subtext"];
                NSString *total = @"";
                for ( NSString *key in st.allKeys ) {
                    total = [total stringByAppendingFormat:@"%@ - %@\n",key,st[key]];
                }
                body = [body stringByAppendingFormat:@"\n\n%@",total];
            }
            [compose setMessageBody:body
                             isHTML:NO];
        }
        
        NSString *email = ui[@"email"];
        if ( email ) {
            [compose setToRecipients:@[email]];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"mail-compose-will-appear"
                                                            object:nil];
        

        compose.mailComposeDelegate = self;
        
        [self presentViewController:compose
                           animated:YES
                         completion:^{
                             [self pushToHiddenVector:[[[Utils del] xfsInterface] view]];
                             [self commitHiddenVector];
                         }];
        
        compose.navigationBar.tintColor = [UIColor whiteColor];
        
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self popHiddenVector];
    
    [[[Utils del] xfsInterface] orangeInterface];
    
    [self dismissViewControllerAnimated:YES completion:^{
        self.mComposer = nil;
        self.mailCompositionDisplaying = NO;
    }];
}


/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end