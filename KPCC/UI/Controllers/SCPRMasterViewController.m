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
    
    [[AudioManager shared] setUserPause:NO];
    
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
    
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    self.hiddenVector = [NSMutableArray new];
    self.mainContentScroller.scrollEnabled = NO;
    
    self.view.backgroundColor = [UIColor blackColor];
    self.horizDividerLine.layer.opacity = 0.0f;
    self.queueBlurView.layer.opacity = 0.0f;
    self.scrubbingUIView.alpha = 0.0f;
    
    self.darkBgView.hidden = NO;
    self.darkBgView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.7];
    self.darkBgView.layer.opacity = 0.0f;
    self.queueBlurView.alpha = 1.0f;
    self.darkBgView.alpha = 1.0f;
    self.onDemandMainDividerView.alpha = 0.4f;
    
    self.deployedProgramTitleConstant = [Utils isThreePointFive] ? 143.0f : 200.0f;
    self.initialProgramTitleConstant = [Utils isThreePointFive] ? 56.0f : 118.0f;
    self.threePointFivePlayControlsConstant = 10.0f;
    
    if ( [Utils isThreePointFive] ) {
        if ( [Utils isIOS8] ) {
            [self.initialControlsYConstraint setConstant:151.0];
            [self.playerControlsTopYConstraint setConstant:288.0];
            [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
        } else {
            [self.initialControlsYConstraint setConstant:101.0];
            [self.playerControlsTopYConstraint setConstant:258.0];
            [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
        }
        
        [self.horizontalDividerPush setConstant:253.0f];
        
    } else {
        [self.programTitleYConstraint setConstant:self.initialProgramTitleConstant];
    }
    
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
    
    [self.queueBlurView setAlpha:0.0];
    [self.queueBlurView setTintColor:[UIColor clearColor]];
    [self.queueDarkBgView setAlpha:0.0];
    
    self.view.alpha = 0.0f;
    [self.letsGoLabel proMediumFontize];
    self.letsGoLabel.alpha = 0.0f;
    
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
    
    [self.shareButton addTarget:self
                         action:@selector(shareButtonTapped:)
               forControlEvents:UIControlEventTouchUpInside
                        special:YES];
    
    [self.cancelSleepTimerButton addTarget:self
                                    action:@selector(cancelSleepTimerAction)
                          forControlEvents:UIControlEventTouchUpInside];
    
    [self setupTimerControls];
    
    self.previousRewindThreshold = 0;
    self.mpvv = [[MPVolumeView alloc] initWithFrame:CGRectMake(-30.0, -300.0, 1.0, 1.0)];
    self.mpvv.alpha = 0.1;
    [self.view addSubview:self.mpvv];
    
    NSLog(@"Program Title Y Lock : %1.1f",self.programTitleYConstraint.constant);
    
    [[NetworkManager shared] setupReachability];
    
    self.originalFrames = [NSMutableDictionary new];

    [self primeScrubber];
    

    [SCPRCloakViewController cloakWithCustomCenteredView:nil cloakAppeared:^{
        if ( [[UXmanager shared] userHasSeenOnboarding] ) {
            
            [self updateDataForUI];
            [self.view layoutIfNeeded];
            [self.liveStreamView layoutIfNeeded];
            [self setupScroller];
            [self.blurView setNeedsDisplay];
            
            [self.mainContentScroller printDimensionsWithIdentifier:@"Main Scroller"];
            [self.liveStreamView printDimensionsWithIdentifier:@"Live Stream View"];
            
            self.originalFrames[@"playerControls"] = @(self.playerControlsBottomYConstraint.constant);
            self.originalFrames[@"programTitle"] = @(self.programTitleYConstraint.constant);
            self.originalFrames[@"liveRewind"] = @(self.liveRewindBottomYConstraint.constant);
            
        } else {
            
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
        self.initialPlayButton.alpha = 0.4;
    }
    
    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[UXmanager shared] beginOnboarding:self];
            
        });
    }
    
    self.viewHasAppeared = YES;
    
}

- (void)viewWillDisappear:(BOOL)animated {
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewDidLayoutSubviews {

    [self.upcomingScreen alignDividerToValue:self.horizDividerLine.frame.origin.y];
    
}

- (void)superPop {
    [self.navigationController popToRootViewControllerAnimated:YES];
    [self decloakForMenu:YES];
    self.navigationItem.title = @"KPCC Live";
}

- (void)setupScroller {
    
    self.mainContentScroller.translatesAutoresizingMaskIntoConstraints = NO;

    self.mainContentScroller.pagingEnabled = YES;
    
    
    self.upcomingScreen = [[SCPRUpcomingProgramViewController alloc] initWithNibName:@"SCPRUpcomingProgramViewController"
                                                                       bundle:nil];
    self.cpFullDetailScreen = [[SCPRCompleteScheduleViewController alloc] initWithNibName:@"SCPRCompleteScheduleViewController"
                                                                                   bundle:nil];
    

    
    self.upcomingScreen.view.frame = self.upcomingScreen.view.frame;
    self.cpFullDetailScreen.view.frame = self.cpFullDetailScreen.view.frame;
    
    CGFloat heightHint = [Utils isThreePointFive] ? self.view.frame.size.height-64.0f : self.liveStreamView.frame.size.height;
    
    NSArray *cpSizeConstraints = [[DesignManager shared] sizeConstraintsForView:self.upcomingScreen.view hints:@{ @"height" : @(heightHint),
                                                                                                            @"width" : @(self.mainContentScroller.frame.size.width)}];
    
    NSArray *fsSizeConstraints = [[DesignManager shared] sizeConstraintsForView:self.cpFullDetailScreen.view hints:@{ @"height" : @(heightHint),
                                                                                                            @"width" : @(self.mainContentScroller.frame.size.width)}];
    
    [self.upcomingScreen.view addConstraints:cpSizeConstraints];
    [self.cpFullDetailScreen.view addConstraints:fsSizeConstraints];
    
    [self.mainContentScroller addSubview:self.upcomingScreen.view];
    [self.mainContentScroller addSubview:self.cpFullDetailScreen.view];
    
    self.upcomingScreen.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.cpFullDetailScreen.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveStreamView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *fConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[mainView][upcomingScreen][cpFull]"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"mainView" : self.liveStreamView,
                                                                               @"upcomingScreen" : self.upcomingScreen.view,
                                                                               @"cpFull" : self.cpFullDetailScreen.view }];
    
    NSArray *fVConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[upcomingScreen]"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"upcomingScreen" : self.upcomingScreen.view }];
    
    /*NSArray *fullScheduleH = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[upcomingScreen][cpFull]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:@{ @"upcomingScreen" : self.upcomingScreen.view,
                                                                                @"cpFull" : self.cpFullDetailScreen.view }];*/
    
    NSArray *fullScheduleV = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cpFull]"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:@{ @"cpFull" : self.cpFullDetailScreen.view }];
    
    [self.mainContentScroller addConstraints:fConstraints];
    [self.mainContentScroller addConstraints:fVConstraints];
    [self.mainContentScroller addConstraints:fullScheduleV];
    
    [self.upcomingScreen.view layoutIfNeeded];
    [self.cpFullDetailScreen.view layoutIfNeeded];
    [self.upcomingScreen.view updateConstraintsIfNeeded];
    [self.cpFullDetailScreen.view updateConstraintsIfNeeded];
    [self.mainContentScroller layoutIfNeeded];
    [self.mainContentScroller updateConstraintsIfNeeded];
    
    [self.upcomingScreen.view printDimensionsWithIdentifier:@"Current Program View"];
    [self.cpFullDetailScreen.view printDimensionsWithIdentifier:@"Full Schedule View"];
    
    self.upcomingScreen.tableToScroll = self.mainContentScroller;
    
    self.mainContentScroller.delegate = self;
    
    if ( [Utils isThreePointFive] ) {
        self.mainContentScroller.contentSize = CGSizeMake(self.mainContentScroller.frame.size.width*3.0,
                                                          self.view.frame.size.height-64.0f);
    } else {
        self.mainContentScroller.contentSize = CGSizeMake(self.mainContentScroller.frame.size.width*3.0,
                                                      self.liveStreamView.frame.size.height);
    }
    
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
            
            self.navigationItem.title = @"KPCC Live";
            
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
        [self.sleepTimerContainerView setAlpha:1.0];
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
    
    
    //nav.navigationBarHidden = YES;
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
    
    [[AudioManager shared] setTemporaryMutex:NO];
    [[AudioManager shared] playOnboardingAudio:3];
}

- (void)onboarding_fin {
    
    [[AudioManager shared] resetPlayer];
    [[AudioManager shared] takedownAudioPlayer];
    
    self.initialPlay = YES;
    
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
        [del.onboardingController ondemandMode];
        [del.window bringSubviewToFront:del.onboardingController.view];
        [UIView animateWithDuration:0.25 animations:^{
            del.onboardingController.view.alpha = 1.0f;
        }];
    } else if ( ![UXmanager shared].settings.userHasViewedScrubbingOnboarding ) {
        SCPRAppDelegate *del = [Utils del];
        [del.onboardingController scrubbingMode];
        [del.window bringSubviewToFront:del.onboardingController.view];
        [UIView animateWithDuration:0.25 animations:^{
            del.onboardingController.view.alpha = 1.0f;
        }];
    }
}

# pragma mark - Actions

- (IBAction)initialPlayTapped:(id)sender {
    
#ifdef FORCE_TEST_STREAM
    self.preRollViewController.tritonAd = nil;
#endif
#ifdef BETA
    self.preRollViewController.tritonAd = nil;
#endif
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) {
        [[UXmanager shared] fadeOutBrandingWithCompletion:^{
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
                BOOL hard = [[AudioManager shared] status] == StreamStatusStopped ? YES : NO;
                [self playAudio:hard];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[SessionManager shared] armProgramUpdater];
            });
            
        }
    } else {
 
        [[AudioManager shared] setUserPause:YES];
        
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            if ( [[AudioManager shared] dropoutOccurred] ) {
                [[AudioManager shared] stopAllAudio];
                [[AudioManager shared] takedownAudioPlayer];
                [[AudioManager shared] buildStreamer:kHLSLiveStreamURL];
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
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[SessionManager shared] disarmProgramUpdater];
        });
        
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
                [[AnalyticsManager shared] logEvent:[NSString stringWithFormat:@"programEpisodeShared%@",[activityType capitalizedString]]
                                     withParameters:@{ @"episodeUrl" : self.onDemandEpUrl,
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
    [[AudioManager shared] backwardSeekFifteenSeconds];
}

- (void)fastForwardFifteen {
    seekRequested = YES;
    [[AudioManager shared] forwardSeekFifteenSeconds];
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
    
    [[AudioManager shared] takedownAudioPlayer];
    
    self.liveStreamView.userInteractionEnabled = YES;
    self.playerControlsView.userInteractionEnabled = YES;
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    
    self.lockPlayback = !play;
    
    [self.jogShuttle endAnimations];
    
    
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
                                       
                                       [[AudioManager shared] setTemporaryMutex:NO];
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
                    if ( self.dirtyFromRewind ) {
                        [[AudioManager shared] specialSeekToDate:cProgram.soft_starts_at];
                    } else {
                        [[AudioManager shared] seekToDate:[cProgram.soft_starts_at dateByAddingTimeInterval:30.0f] forward:NO failover:NO];
                    }
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
        [[AudioManager shared] forwardSeekLive];
        
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
    self.scrubbingUI.rw30Button = self.back30Button;
    self.scrubbingUI.fw30Button = self.fwd30Button;

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
    
    CGFloat adjustment = [Utils isThreePointFive] ? 90.0 : 0.0f;
    self.scrubbingTriggerView.frame = CGRectMake(0.0, self.progressView.frame.origin.y-self.scrubbingTriggerView.frame.size.height+20.0-adjustment,
                                                 self.scrubbingTriggerView.frame.size.width,
                                                 self.scrubbingTriggerView.frame.size.height);
    
    [self.view addSubview:self.scrubbingTriggerView];
    
    self.back30VerticalAnchor.constant = [Utils isThreePointFive] ? 28.0 : 40.0f;
    self.fwd30VerticalAnchor.constant = [Utils isThreePointFive] ? 28.0 : 40.0f;
    self.scrubbingUI.parentControlView = self;
    self.scrubbingTriggerView.alpha = 0.0f;
    
    sUI.view.alpha = 0.0f;

    [self.scrubbingUI prerender];
    
}

- (void)bringUpScrubber {
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnDemand &&
        [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
        return;
    }
    
    if ( self.scrubberLoadingGate ) return;
    
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
    
    [UIView animateWithDuration:0.25 animations:^{
        self.queueBlurView.alpha = 1.0f;
        self.queueDarkBgView.alpha = 0.45f;
    }];

    
    /*
    self.scrubbingTriggerView.alpha = 0.0f;
    self.timeLabelOnDemand.alpha = 0.0f;
    self.progressView.alpha = 0.0f;
    self.queueBlurView.alpha = 1.0f;
    self.onDemandPlayerView.alpha = 0.0f;
    self.horizDividerLine.alpha = 0.0f;
    self.programTitleLabel.alpha = 0.0f;
    self.queueDarkBgView.alpha = 0.45;
    */
    
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
    
    /*
    self.scrubbingTriggerView.alpha = 1.0f;
    self.timeLabelOnDemand.alpha = 1.0f;
    self.progressView.alpha = 1.0f;
    self.onDemandPlayerView.alpha = 1.0f;
    self.horizDividerLine.alpha = 0.4;
    self.programTitleLabel.alpha = 1.0f;
    */
    
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
        
        [[AudioManager shared] setDelegate:self];
        if ( ![[AudioManager shared] isPlayingAudio] ) {
            [self tickOnDemand];
        }
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

# pragma mark - UI control
- (void)prettifyBehindLiveStatus {
    
    NSDate *ciCurrentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    if ( !ciCurrentDate ) {
        self.liveDescriptionLabel.text = @"";
        return;
    }
#ifndef SUPPRESS_V_LIVE
    NSTimeInterval ti = [[[SessionManager shared] vLive] timeIntervalSinceDate:ciCurrentDate];
#else
    NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:ciCurrentDate];
#endif
    
#ifndef SUPPRESS_V_LIVE
    if ( ti > 60*60*24 ) {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            [self.liveDescriptionLabel setText:@"UP NEXT"];
        } else {
            [self.liveDescriptionLabel setText:@"LIVE"];
            self.dirtyFromRewind = NO;
        }
        return;
    }
#endif
    
    if ( [[NetworkManager shared] networkDown] ) {
        [self.liveDescriptionLabel setText:@"NO NETWORK"];
        return;
    }
    
    if ( ti > kToleratedIncreaseInDrift ) {
        [self.liveDescriptionLabel setText:[NSString stringWithFormat:@"%@ BEHIND LIVE", [NSDate prettyTextFromSeconds:ti]]];
        self.previousRewindThreshold = [[AudioManager shared].audioPlayer.currentItem.currentDate timeIntervalSince1970];
    } else {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            [self.liveDescriptionLabel setText:@"UP NEXT"];
        } else {
            [self.liveDescriptionLabel setText:@"LIVE"];
            self.dirtyFromRewind = NO;
        }
    }
}

- (void)updateDataForUI {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        if ( returnedObject ) {
            
            [self.liveProgressViewController displayWithProgram:(Program*)returnedObject
                                                         onView:self.view
                                               aboveSiblingView:self.playerControlsView];
            [self.liveProgressViewController hide];
            [self determinePlayState];
            
            [self.upcomingScreen primeWithProgramBasedOnCurrent:returnedObject];
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
    
    CGFloat constant = [Utils isThreePointFive] ? 133.0f : 200.0f;
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
    
    self.navigationItem.title = @"KPCC Live";
    [self primeRemoteCommandCenter:YES];
    
    if ([self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:NO];
    }
    
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
    
    setForLiveStreamUI = YES;
    
    [self moveTextIntoPlace:NO];
    
    [self.view layoutIfNeeded];
    
    self.liveDescriptionLabel.text = @"LIVE";
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    
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
    
    if (![self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:YES];
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
    
    UIImage *img = [[DesignManager shared] currentBlurredImage];
    self.queueBlurView.image = img;
    [[DesignManager shared] setProtectBlurredImage:YES];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.jogShuttle.view.alpha = 1.0f;
        self.timeLabelOnDemand.alpha = 1.0f;
        self.queueBlurView.layer.opacity = 1.0f;
        self.scrubbingTriggerView.alpha = 1.0f;
        self.liveProgressViewController.view.alpha = 0.0f;
        [self.liveProgressViewController hide];
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
        
        if ( !programObj ) {
            [self updateUIWithProgram:nil];
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
        [self primeManualControlButton];
        
        self.view.alpha = 1.0f;
        
        if ( !self.scrubbing ) {
            self.scrubbingUI.view.alpha = 0.0f;
        }
        
        if ( [SCPRCloakViewController cloakInUse] ) {
            [SCPRCloakViewController uncloak];
        }

        [self.programImageView printDimensionsWithIdentifier:@"programImage"];
        [self.queueBlurView printDimensionsWithIdentifier:@"queueBlurImage"];
        
        UIImage *blurry = [self.programImageView.image blurredImageWithRadius:20.0f
                                                                   iterations:3
                                                                    tintColor:[UIColor clearColor]];
        
        NSLog(@"Image : %1.1f, %1.1f",blurry.size.width,blurry.size.height);
        
        self.queueBlurView.image = blurry;
        
    });
}

- (void)updateUIWithProgram:(Program*)program {
    if (!program) {
        self.programTitleLabel.text = @"";
        self.liveDescriptionLabel.text = @"NO NETWORK";
        return;
    }
    
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
                } else {
                    bottomAnim.toValue = @(self.threePointFivePlayControlsConstant);
                }
            }
            
            self.liveDescriptionLabel.text = @"";
            
            
            
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
                
                self.scrubbingTriggerView.alpha = 1.0f;
                self.mainContentScroller.scrollEnabled = YES;
                
                if ( !self.preRollViewController.tritonAd ) {
                    if ( [[UXmanager shared] userHasSeenOnboarding] ) {
                        self.initialPlay = YES;
                        if ( self.initiateRewind ) {
                            [self activateRewind:RewindDistanceBeginning];
                        } else {
                            [self playAudio:YES];
                        }
                        
                    } else {
                        [[UXmanager shared] beginAudio];
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
    if ( viewToHide.alpha > 0.0f ) {
        [self.hiddenVector addObject:@{ @"view" : viewToHide, @"alpha" : @(viewToHide.alpha) }];
    }
}

- (void)commitHiddenVector {
    [UIView animateWithDuration:0.275 animations:^{
        for ( NSDictionary *th in self.hiddenVector ) {
            UIView *v2h = th[@"view"];
            v2h.alpha = 0.0f;
        }
    }];
}

- (void)popHiddenVector {
    [UIView animateWithDuration:0.275 animations:^{
        for ( NSDictionary *th in self.hiddenVector ) {
            UIView *v2h = th[@"view"];
            v2h.alpha = [th[@"alpha"] floatValue];
        }
    } completion:^(BOOL finished) {
        [self.hiddenVector removeAllObjects];
    }];
}

#pragma mark - Util



#pragma mark - Menu control

- (void)cloakForMenu:(BOOL)animated {
    
    if ( [AudioManager shared].currentAudioMode == AudioModePreroll ) return;
    
    self.menuOpen = YES;
    
    [self removeAllAnimations];
    
    self.pulldownMenu.alpha = 1.0f;
    [self.liveProgressViewController hide];
    
    self.navigationItem.title = @"Menu";
    if (animated) {
        [pulldownMenu openDropDown:YES];
    } else {
        [pulldownMenu openDropDown:NO];
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
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveRewindAltButton.alpha = 0.0f;
    }];
    
    POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    dividerFadeAnim.toValue = @0;
    dividerFadeAnim.duration = 0.3;
    [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerOutFadeAnimation"];
    
    self.scrubbingTriggerView.alpha = 0.0f;
    

}

- (void)decloakForMenu:(BOOL)animated {
    
    if ( [AudioManager shared].currentAudioMode == AudioModePreroll ) return;
    
    if ( !self.menuOpen ) return;
    
    self.menuOpen = NO;
    
    [self removeAllAnimations];
    
    if (setForOnDemandUI) {
        self.navigationItem.title = @"Programs";
    } else {
        self.navigationItem.title = @"KPCC Live";
    }
    
    if (animated) {
        [pulldownMenu closeDropDown:YES];
    } else {
        [pulldownMenu closeDropDown:NO];
    }
    
    NSNumber *restoredAlpha = [[NetworkManager shared] networkDown] ? @.45 : @1;
    
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = restoredAlpha;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeInAnimation"];
    }
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.0f;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeIn = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeIn.toValue = @1.0f;
    controlsFadeIn.duration = 0.3;
    
    POPBasicAnimation *cfi = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    cfi.toValue = restoredAlpha;
    cfi.duration = 0.3;
    
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
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
    }
    //}
    if ( [AudioManager shared].currentAudioMode == AudioModeLive && !setForOnDemandUI ) {
        [self.liveProgressViewController show];
    } else {
        [self.liveProgressViewController hide];
    }
    
    if ( [[NetworkManager shared] networkDown] ) {
        self.initialPlayButton.alpha = 0.4;
        self.playPauseButton.alpha = 0.4;
    }
    
    [self primeManualControlButton];
    
    self.scrubbingTriggerView.alpha = 1.0f;
    
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
    
    [[AudioManager shared] setCurrentAudioMode:AudioModePreroll];
    [[UXmanager shared] hideMenuButton];
    
    [self removeAllAnimations];
    
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
    
    self.preRollOpen = YES;
    [self.view bringSubviewToFront:self.playerControlsView];
    
}

- (void)decloakForPreRoll:(BOOL)animated {
    [self removeAllAnimations];
    
    
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
    
    
    self.preRollOpen = NO;
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
        
        self.dividerLineRightAnchor.constant = 0.0f;
        self.dividerLineLeftAnchor.constant = 0.0f;
        
        [UIView animateWithDuration:0.25f animations:^{
            
            [self.liveStreamView layoutIfNeeded];
            
            SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
            SCPRNavigationController *nav = del.masterNavigationController;
            
            self.queueBlurView.alpha = 1.0f;
            self.queueDarkBgView.alpha = 0.4f;
            [self pushToHiddenVector:self.playerControlsView];
            [self pushToHiddenVector:self.initialControlsView];
            [self pushToHiddenVector:nav.menuButton];
            
            [self commitHiddenVector];
            
        }];
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
        [UIView animateWithDuration:0.25f animations:^{
            if ( self.mainContentScroller.contentOffset.x == 0.0f ) {
                self.queueBlurView.alpha = 0.0f;
                self.queueDarkBgView.alpha = 0.0f;
                self.scrubbingTriggerView.alpha = 1.0f;
                self.dividerLineRightAnchor.constant = -5.0f;
                self.dividerLineLeftAnchor.constant = 5.0f;
                [self.liveStreamView layoutIfNeeded];
                
                [self popHiddenVector];
            } else {
                self.scrubbingTriggerView.alpha = 0.0f;
            }
        }];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
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
    
    [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeSkipped];
    
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
    
    NSString *event = @"";
    switch (indexPath.row) {
        case 0:
        {
            event = @"menuSelectionLiveStream";
            if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
                [self decloakForMenu:YES];
            } else {
                [self decloakForMenu:YES];
                [self goLive:YES];
            }
            break;
        }
            
        case 1:
        {
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
            
            event = @"menuSelectionHeadlines";
            SCPRShortListViewController *slVC = [[SCPRShortListViewController alloc] initWithNibName:@"SCPRShortListViewController"
                                                                                              bundle:nil];
            [self.navigationController pushViewController:slVC animated:YES];
            break;
            
        }
        case 3: {
            
            event = @"menuSelectionWakeSleep";
            SCPRTimerControlViewController *timer = [[SCPRTimerControlViewController alloc] initWithNibName:@"SCPRTimerControlViewController"
                                                                                                     bundle:nil];
            
            CGSize bounds = [[UIScreen mainScreen] bounds].size;
            timer.view.frame = CGRectMake(0.0,0.0,bounds.width,bounds.height);
            
            
            [self.navigationController pushViewController:timer
                                                 animated:YES];
            
            [timer setup];
            
            break;
        }
        case 4: {
            event = @"menuSelectionDonate";
            NSString *urlStr = @"https://scprcontribute.publicradio.org/contribute.php?refId=iphone&askAmount=60";
            NSURL *url = [NSURL URLWithString:urlStr];
            [self decloakForMenu:YES];
            [[UIApplication sharedApplication] openURL:url];
            break;
        }
        case 5: {
            
            event = @"menuSelectionFeedback";
            SCPRFeedbackViewController *fbVC = [[SCPRFeedbackViewController alloc] initWithNibName:@"SCPRFeedbackViewController"
                                                                                            bundle:nil];
            [self.navigationController pushViewController:fbVC animated:YES];
            break;
            
        }
        default: {
            [self decloakForMenu:YES];
            break;
        }
    }
    
    [[AnalyticsManager shared] logEvent:event
                         withParameters:@{}];
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
        
        if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
            if ( !self.menuOpen ) {
                if ( self.liveStreamView.layer.opacity < 1.0 ) {
                    [UIView animateWithDuration:0.25 animations:^{
                        NSLog(@"Opacity was affected");
                        self.liveStreamView.layer.opacity = 1.0f;
                    }];
                }
            }
        }
        
        if (setForOnDemandUI) {
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
        
        
        if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
            if ( self.liveRewindAltButton.alpha == 1.0 || self.liveRewindAltButton.layer.opacity == 1.0 )
                [self primeManualControlButton];
        }
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
        
        [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:currentTime
                                                                 andDuration:duration]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView setProgress:(currentTime / duration) animated:YES];
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

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end