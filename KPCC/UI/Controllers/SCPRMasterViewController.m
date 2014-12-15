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

@import MessageUI;

static NSString *kRewindingText = @"REWINDING...";
static NSString *kForwardingText = @"GOING LIVE...";
static NSString *kBufferingText = @"BUFFERING";

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

- (void)playStream:(BOOL)hard;
- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk;
- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk completion:(CompletionBlock)completion;

@end

@implementation SCPRMasterViewController

@synthesize pulldownMenu,
seekRequested,
initialPlay,
setPlaying,
busyZoomAnim,
setForLiveStreamUI,
setForOnDemandUI;

#pragma mark - UIViewController

// Allows for interaction with system audio controls.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay ||
            event.subtype == UIEventSubtypeRemoteControlPause ||
            event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            //            [self playOrPauseTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            //            [self nextEpisodeTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
            //            [self prevEpisodeTapped:nil];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.horizDividerLine.layer.opacity = 0.0;
    
    //self.initialControlsView.backgroundColor = [UIColor redColor];
    //self.initialPlayButton.backgroundColor = [UIColor blueColor];
    
    if ( [Utils isThreePointFive] ) {
        if ( [Utils isIOS8] ) {
            [self.initialControlsYConstraint setConstant:131.0];
            [self.playerControlsTopYConstraint setConstant:288.0];
        } else {
            [self.initialControlsYConstraint setConstant:101.0];
            [self.playerControlsTopYConstraint setConstant:258.0];
            [self.programTitleYConstraint setConstant:278.0];
        }
    }
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    self.liveProgressViewController = [[SCPRProgressViewController alloc] init];
    self.liveProgressViewController.view = self.liveProgressView;
    self.liveProgressViewController.liveProgressView = self.liveProgressBarView;
    self.liveProgressViewController.currentProgressView = self.currentProgressBarView;
    self.playerControlsView.backgroundColor = [UIColor clearColor];
    
    self.queueBlurView.contentMode = UIViewContentModeCenter;
    
    self.liveRewindAltButton.userInteractionEnabled = NO;
    [self.liveRewindAltButton setAlpha:0.0];
    
    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    pulldownMenu.delegate = self;
    [self.view addSubview:pulldownMenu];
    [pulldownMenu loadMenu];
    
    // Set up pre-roll child view controller.
    [self addPreRollController];
    
    // Fetch program info and update audio control state.
    //[self updateDataForUI];
    
    // Observe when the application becomes active again, and update UI if need-be.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDataForUI) name:UIApplicationWillEnterForegroundNotification object:nil];
    
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
    self.jogShuttle.view.alpha = 0.0;
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
                                                 name:@"program_has_changed"
                                               object:nil];
    
    [self.queueBlurView setAlpha:0.0];
    [self.queueBlurView setTintColor:[UIColor clearColor]];
    [self.queueDarkBgView setAlpha:0.0];
    
    self.view.alpha = 0.0;
    [self.letsGoLabel proMediumFontize];
    self.letsGoLabel.alpha = 0.0;
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] loadOnboarding];
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
    
    self.previousRewindThreshold = 0;
    self.mpvv = [[MPVolumeView alloc] initWithFrame:CGRectMake(-30.0, -300.0, 1.0, 1.0)];
    self.mpvv.alpha = 0.1;
    [self.view addSubview:self.mpvv];
    
    NSLog(@"Program Title Y Lock : %1.1f",self.programTitleYConstraint.constant);
    
    [SCPRCloakViewController cloakWithCustomCenteredView:nil cloakAppeared:^{
        if ( [[UXmanager shared] userHasSeenOnboarding] ) {
            [self updateDataForUI];
            [self.view layoutIfNeeded];
            [self.liveStreamView layoutIfNeeded];
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
    
    
    [self.blurView setNeedsDisplay];
    [self.queueBlurView setNeedsDisplay];
    
    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[UXmanager shared] beginOnboarding:self];
            
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.queueBlurView.alpha = 0.0;
    self.queueDarkBgView.alpha = 0.0;
}

- (void)addPreRollController {
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) return;
    
    self.preRollViewController = [[SCPRPreRollViewController alloc] initWithNibName:nil bundle:nil];
    self.preRollViewController.delegate = self;
    
    [[NetworkManager shared] fetchTritonAd:nil completion:^(TritonAd *tritonAd) {
        self.preRollViewController.tritonAd = tritonAd;
    }];
    
    [self addChildViewController:self.preRollViewController];
    
    CGRect frame = self.view.bounds;
    frame.origin.y = (-1)*self.view.bounds.size.height;
    self.preRollViewController.view.frame = frame;
    
    [self.view addSubview:self.preRollViewController.view];
    [self.preRollViewController didMoveToParentViewController:self];
}

#pragma mark - Onboarding
- (void)primeOnboarding {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = [del masterNavigationController];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    //nav.navigationBarHidden = YES;
    
    self.automationMode = YES;
    self.programImageView.image = [UIImage imageNamed:@"onboarding-tile.jpg"];
    self.initialControlsView.layer.opacity = 0.0;
    self.liveStreamView.alpha = 0.0;
    self.liveDescriptionLabel.alpha = 0.0;
    self.pulldownMenu.alpha = 0.0;
    
    self.programTitleLabel.font = [UIFont systemFontOfSize:30.0];
    [self.programTitleLabel proLightFontize];
    self.liveProgressViewController.view.alpha = 0.0;
    nav.navigationBarHidden = NO;
    [[SessionManager shared] fetchOnboardingProgramWithSegment:1 completed:^(id returnedObject) {
        [self.blurView setNeedsDisplay];
        self.programTitleLabel.text = @"Welcome to KPCC";
        [SCPRCloakViewController uncloak];
        [UIView animateWithDuration:0.33 animations:^{
            self.view.alpha = 1.0;
            [self.blurView.layer setOpacity:1.0];
            self.darkBgView.layer.opacity = 0.0;
            nav.menuButton.alpha = 0.0;
        } completion:^(BOOL finished) {
            [[UXmanager shared] fadeInBranding];
        }];
    }];
}

- (void)onboarding_revealPlayerControls {
    [UIView animateWithDuration:0.2 animations:^{
        self.letsGoLabel.alpha = 1.0;
    }];
    
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 1.0f;
    
    [self.initialControlsView.layer pop_addAnimation:scaleAnimation forKey:@"revealPlayer"];
    self.initialControlsView.layer.opacity = 1.0;
    
}

- (void)onboarding_beginOnboardingAudio {
    [self.liveProgressViewController displayWithProgram:[[SessionManager shared] currentProgram]
                                                 onView:self.view
                                       aboveSiblingView:self.playerControlsView];
    [self.liveProgressViewController hide];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveProgressViewController.view.alpha = 1.0;
        self.liveStreamView.alpha = 1.0;
        
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
    [self addPreRollController];
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveDescriptionLabel.alpha = 1.0;
        del.masterNavigationController.menuButton.alpha = 1.0;
        [self.darkBgView.layer setOpacity:0.0];
        self.onDemandPlayerView.alpha = 0.0;
    }];
    
    [[UXmanager shared].settings setUserHasViewedOnboarding:YES];
#ifdef PRODUCTION
    [[UXmanager shared] persist];
#endif
    
    [self updateDataForUI];
}

- (void)showOnDemandOnboarding {
    if ( ![UXmanager shared].settings.userHasViewedOnDemandOnboarding ) {
        SCPRAppDelegate *del = [Utils del];
        [del.onboardingController ondemandMode];
        [del.window bringSubviewToFront:del.onboardingController.view];
        [UIView animateWithDuration:0.25 animations:^{
            del.onboardingController.view.alpha = 1.0;
        }];
    }
}

# pragma mark - Actions

- (IBAction)initialPlayTapped:(id)sender {
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) {
        [[UXmanager shared] fadeOutBrandingWithCompletion:^{
            [self moveTextIntoPlace:YES];
            [self primePlaybackUI:YES];
            self.initialPlay = YES;
        }];
        return;
    }
    

    
    [UIView animateWithDuration:0.15 animations:^{
        self.liveRewindAltButton.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (self.preRollViewController.tritonAd) {
            [self cloakForPreRoll:YES];
            [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
                [self primePlaybackUI:YES];
            }];
        } else {
            [self primePlaybackUI:YES];
            self.initialPlay = YES;
        }
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
    
    if (![[AudioManager shared] isStreamPlaying]) {
        if ( [[SessionManager shared] sessionIsExpired] ) {
            [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
                if ([[AudioManager shared] isStreamBuffering]) {
                    [[AudioManager shared] stopAllAudio];
                } else {
                    [self playStream:YES];
                }
            }];
        } else {
            if ( [[UXmanager shared] onboardingEnding] ) {
                [[UXmanager shared] setOnboardingEnding:NO];
                [self playStream:YES];
            } else {
                [self playStream:NO];
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[SessionManager shared] armProgramUpdater];
            });
            
        }
    } else {
        self.setPlaying = NO;
        [self pauseStream];
        
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
    if ([[AudioManager shared] isStreamPlaying]) {
        [self pauseStream];
    }
}
- (void)playTapped:(id)sender {
    if (![[AudioManager shared] isStreamPlaying]) {
        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
        }
        [self playStream:YES];
    }
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
    [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
        
    }];
}

# pragma mark - Audio commands
- (void)playStream:(BOOL)hard {
    if ( hard ) {
        [[AudioManager shared] playLiveStream];
    } else {
        [[AudioManager shared] playStream];
        [[SessionManager shared] startLiveSession];
    }
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
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
    
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) return;
    
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    self.lockPlayback = !play;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"audio_player_began_playing"
                                                  object:nil];
    [self.jogShuttle endAnimations];
    
    
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        
        [self setLiveStreamingUI:YES];
        [self treatUIforProgram];
        
        if ( play ) {
            if ( self.initialPlay ) {
                if ( self.preRollViewController.tritonAd ) {
                    [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
                        
                    }];
                }
                [[AudioManager shared] playLiveStream];
            } else {
                [self initialPlayTapped:nil];
            }
        }
    }];
    
}

- (void)activateRewind:(RewindDistance)distance {
    
    self.initiateRewind = NO;
    [self snapJogWheel];
    [self.liveDescriptionLabel pulsate:kRewindingText color:nil];
    
    self.jogShuttle.forceSingleRotation = YES;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.liveRewindAltButton.alpha = 0.0;
    }];
    
    self.jogging = YES;
    self.shuttlingGate = YES;
    
    // Disable this until the stream separates from the beginning
    // of the program a litle bit
    // self.liveRewindAltButton.userInteractionEnabled = NO;
    // [self.liveRewindAltButton setAlpha:kDisabledAlpha];
    
    Program *cProgram = [[SessionManager shared] currentProgram];
    [self.jogShuttle.view setAlpha:1.0];
    
    
    BOOL sound = [AudioManager shared].currentAudioMode == AudioModeOnboarding ? NO : YES;
    [self.jogShuttle animateWithSpeed:0.8
                         hideableView:self.playPauseButton
                            direction:SpinDirectionBackward
                            withSound:sound
                           completion:^{
                               
                               [self.liveDescriptionLabel stopPulsating];
                               
                               self.dirtyFromRewind = YES;
                               self.initiateRewind = NO;
                               self.jogging = NO;
                               [self updateControlsAndUI:YES];
                               
                               seekRequested = NO;
                               
                               if ( [[UXmanager shared] userHasSeenOnboarding] ) {
                                   
                                   [[SessionManager shared] invalidateSession];
                                   [[SessionManager shared] setRewindSessionIsHot:YES];
                                   [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                       
                                   }];
                                   
                               } else {
                                   
                                   [[SessionManager shared] fetchOnboardingProgramWithSegment:2 completed:^(id returnedObject) {
                                       
                                       [[AudioManager shared] setTemporaryMutex:NO];
                                       [[AudioManager shared] playOnboardingAudio:2];
                                       [[UXmanager shared] restoreInteractionButton];
                                       
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
                        [[AudioManager shared] seekToDate:cProgram.soft_starts_at forward:NO failover:NO];
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
        self.liveRewindAltButton.alpha = 0.0;
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
                                   
                                   [self.liveDescriptionLabel stopPulsating];
                                   self.jogging = NO;
                                   self.dirtyFromRewind = NO;
                                   [self updateControlsAndUI:YES];
                                   
                                   [[SessionManager shared] setSeekForwardRequested:NO];
                                   [[SessionManager shared] invalidateSession];
                                   
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



# pragma mark - UI control
- (void)updateDataForUI {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self.liveProgressViewController displayWithProgram:(Program*)returnedObject
                                                     onView:self.view
                                           aboveSiblingView:self.playerControlsView];
        [self.liveProgressViewController hide];
        [self determinePlayState];
      
        if ( [[UXmanager shared] onboardingEnding] ) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self primeManualControlButton];
            });
        }
        
    }];
}


- (void)moveTextIntoPlace:(BOOL)animated {
    
    CGFloat constant = 200;
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
            
            self.liveDescriptionLabel.alpha = 1.0;
            
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
                [self.jogShuttle.view setAlpha:0.0];
            }];
            
        }];
    }
}

- (void)setUIPositioning {
    
}

- (void)determinePlayState {
    if ( [[AudioManager shared] status] == StreamStatusStopped ) {
        if ( [[SessionManager shared] sessionIsInRecess] ) {
            self.liveDescriptionLabel.text = @"UP NEXT";
        } else {
            if ( [AudioManager shared].currentAudioMode != AudioModeOnboarding )
                self.liveDescriptionLabel.text = @"ON NOW";
        }
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
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"audio_player_began_playing"
                                                  object:nil];
    
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
    
    self.queueBlurView.alpha = 0.0;
    self.queueDarkBgView.alpha = 0.0;
    
    setForLiveStreamUI = YES;
    
    [self moveTextIntoPlace:NO];
    
    [self.view layoutIfNeeded];
    
    self.liveDescriptionLabel.text = @"LIVE";
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    
}

- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index {
    
    [self snapJogWheel];
    
    self.onDemandGateCount = 0;
    
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
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.jogShuttle.view.alpha = 1.0;
        self.timeLabelOnDemand.alpha = 1.0;
        self.queueBlurView.alpha = 1.0;
    } completion:^(BOOL finished) {
        
        [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
            self.playPauseButton.enabled = YES;
            [self setUIContents:YES];
        }];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(rebootOnDemandUI)
                                                     name:@"audio_player_began_playing"
                                                   object:nil];
        
        setForOnDemandUI = YES;
        setForLiveStreamUI = NO;
        
        if (self.menuOpen) {
            [self decloakForMenu:NO];
        }
        
        [[SessionManager shared] setCurrentProgram:nil];
        [self.liveProgressViewController hide];
        
        self.navigationItem.title = @"Programs";

        [self.progressView setProgress:0.0 animated:YES];
        self.progressView.alpha = 1.0;
        self.queueScrollView.alpha = 1.0;
        self.onDemandPlayerView.alpha = 1.0;
        self.queueDarkBgView.alpha = 0.0;
        
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
        for (int i = 0; i < [array count]; i++) {
            CGRect frame;
            frame.origin.x = self.queueScrollView.frame.size.width * i;
            frame.origin.y = 0;
            frame.size = self.queueScrollView.frame.size;
            
            SCPRQueueScrollableView *queueSubView = [[SCPRQueueScrollableView alloc] initWithFrame:frame];
            [queueSubView setAudioChunk:array[i]];
            
            [self.queueScrollView addSubview:queueSubView];
        }
        
        self.queueScrollView.contentSize = CGSizeMake(self.queueScrollView.frame.size.width * [array count], self.queueScrollView.frame.size.height);
        [self setPositionForQueue:index animated:NO];
        [self.queueScrollView setHidden:NO];
        
        __block SCPRMasterViewController *weakSelf = self;
        [self setDataForOnDemand:program andAudioChunk:array[index] completion:^{
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                weakSelf.timeLabelOnDemand.alpha = 0.0;
                weakSelf.progressView.alpha = 0.0;
                weakSelf.shareButton.alpha = 0.0;
            } completion:^(BOOL finished){
                
                if (!weakSelf.queueBlurShown) {
                    [[AudioManager shared] setCurrentAudioMode:AudioModeOnDemand];
                    [weakSelf.navigationController popToRootViewControllerAnimated:YES];
                }
                
                [[QueueManager shared] playItemAtPosition:[[QueueManager shared] currentlyPlayingIndex]];
                
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
                                              [self.blurView setNeedsDisplay];
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
}

- (void)treatUIforProgram {
    Program *programObj = [[SessionManager shared] currentProgram];
    // Only update background image when we're not in On Demand mode.
    if (!setForOnDemandUI){
        [[DesignManager shared] loadProgramImage:programObj.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          
                                          [self.blurView setNeedsDisplay];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              
                                              [self updateUIWithProgram:programObj];
                                              [[AudioManager shared] updateNowPlayingInfoWithAudio:programObj];
                                              self.navigationController.navigationBarHidden = NO;
                                              
                                              [self.view layoutIfNeeded];
                                              [self.liveStreamView layoutIfNeeded];
                                              [self.initialControlsView layoutIfNeeded];
                                              [self.liveRewindAltButton layoutIfNeeded];
                                              
                                              [self primeManualControlButton];
                                              
                                              self.view.alpha = 1.0;
                                              if ( [SCPRCloakViewController cloakInUse] ) {
                                                  [SCPRCloakViewController uncloak];
                                              }
                                          });
                                          
                                      }];
    } else {
        
        [self updateUIWithProgram:programObj];
        self.view.alpha = 1.0;
        
    }
    
}

- (void)updateUIWithProgram:(Program*)program {
    if (!program) {
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
            self.initialControlsView.alpha = 0.0;
            self.letsGoLabel.alpha = 0.0;
            self.liveStreamView.alpha = 1.0;
            [self.programTitleYConstraint setConstant:200.0];
            [self.liveStreamView layoutIfNeeded];
            if ( !self.preRollViewController.tritonAd ) {
                if ( self.initiateRewind ) {
                    self.playPauseButton.alpha = 0.0;
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
                }
            }
            
            self.liveDescriptionLabel.text = @"";
            [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];
            
            // Hide or show divider depending on screen size
            self.horizDividerLine.layer.opacity = 0.0;
            if ( !suppressDivider ) {
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
                
                if ( !self.preRollViewController.tritonAd ) {
                    if ( [[UXmanager shared] userHasSeenOnboarding] ) {
                        self.initialPlay = YES;
                        if ( self.initiateRewind ) {
                            //self.initiateRewind
                            [self activateRewind:RewindDistanceBeginning];
                        } else {
                            [self playStream:YES];
                        }
                        
                    } else {
                        [[UXmanager shared] beginAudio];
                    }
                }
                
            }];
            [self.initialControlsView.layer pop_addAnimation:fadeControls forKey:@"fadeDownInitialControls"];
            
            self.lockAnimationUI = NO;
            
        }];
        
    } else {
        self.initialPlayButton.alpha = 0.0;
        self.initialControlsView.alpha = 0.0;
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
    if ( [[AudioManager shared] status] == StreamStatusStopped && [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because onboarding initial state");
        okToShow = NO;
    }
    if ( [[AudioManager shared] status] == StreamStatusPlaying ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because audio is playing");
        okToShow = NO;
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because Audio Mode is onDemand");
        okToShow = NO;
    }
    if ( [self jogging] ) {
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
    

    if ( [[SessionManager shared] sessionIsInRecess] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because we're in no-mans-land");
        okToShow = NO;
    }
    
    
    if ( [[UXmanager shared] onboardingEnding] ) {
        if ( okToShow )
            NSLog(@"Rewind Button - Hiding because onboarding is ending");
        okToShow = NO;
    }
    
    if ( okToShow ) {
        self.onboardingRewindButtonShown = YES;
        self.liveRewindAltButton.userInteractionEnabled = YES;
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 1.0;
        }];
    } else {
        self.liveRewindAltButton.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 0.0;
        }];
    }
    
}

#pragma mark - Util



#pragma mark - Menu control

- (void)cloakForMenu:(BOOL)animated {
    [self removeAllAnimations];
    
    self.pulldownMenu.alpha = 1.0;
    
    [self.liveProgressViewController hide];
    
    self.navigationItem.title = @"Menu";
    
    [self.blurView setNeedsDisplay];
    
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
    darkBgFadeAnimation.toValue = @0.75;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *lsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    lsFade.toValue = @(0);
    lsFade.duration = 0.3;
    
    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:lsFade forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"initialControlsViewFade"];
    }
    
    [UIView animateWithDuration:0.33 animations:^{
        self.liveRewindAltButton.alpha = 0.0;
    }];
    
    POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    dividerFadeAnim.toValue = @0;
    dividerFadeAnim.duration = 0.3;
    [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerOutFadeAnimation"];
    
    
    self.menuOpen = YES;
}

- (void)decloakForMenu:(BOOL)animated {
    [self removeAllAnimations];
    
    if (setForOnDemandUI) {
        self.navigationItem.title = @"Programs";
    } else {
        self.navigationItem.title = @"KPCC Live";
    }
    
    [self.blurView setNeedsDisplay];
    
    if (animated) {
        [pulldownMenu closeDropDown:YES];
    } else {
        [pulldownMenu closeDropDown:NO];
    }
    
    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @1;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeInAnimation"];
    }
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;
    
    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.0;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeIn = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeIn.toValue = @1;
    controlsFadeIn.duration = 0.3;
    
    POPBasicAnimation *cfi = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    cfi.toValue = @1;
    cfi.duration = 0.3;
    
    [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
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
    if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
        [self.liveProgressViewController show];
    }
    self.menuOpen = NO;
}

- (void)removeAllAnimations {
    [self.blurView.layer pop_removeAllAnimations];
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
    [self removeAllAnimations];
    [self.blurView setNeedsDisplay];
    
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
    darkBgFadeAnimation.toValue = @0.0;
    darkBgFadeAnimation.duration = 0.3;
    
    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;
    
    
    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
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
    
    [self.blurView setNeedsDisplay];
    
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
    
    [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
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

- (void)preRollCompleted {
    if ( self.lockPreroll ) {
        self.lockPreroll = NO;
        return;
    }
    
    [self.preRollViewController removeFromParentViewController];
    [self.preRollViewController.view removeFromSuperview];
    
    self.preRollViewController.tritonAd = nil;
    self.lockPreroll = YES;
    self.initialPlay = YES;
    
    if ( [Utils isThreePointFive] ) {
        POPSpringAnimation *bottomAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
        bottomAnim.toValue = @(0);
        [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];
        
        self.horizDividerLine.layer.opacity = 0.4;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.preRollOpen) {
            [self decloakForPreRoll:YES];
        }

        if ( self.initiateRewind ) {
            [[AudioManager shared] takedownAudioPlayer];
            [self activateRewind:RewindDistanceBeginning];
        } else {
            if ( [[AudioManager shared].audioPlayer rate] == 0.0 ) {
                [self playStream:YES];
            }
        }
        
    });
    
}


#pragma mark - UIScrollViewDelegate for audio queue
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSLog(@"Will begin dragging ... ");
    [self onDemandFadeDown];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    int newPage = scrollView.contentOffset.x / scrollView.frame.size.width;
    if (self.queueCurrentPage == newPage) {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.timeLabelOnDemand.alpha = 1.0;
            self.progressView.alpha = 1.0;
            self.queueBlurView.alpha = 0.0;
            self.queueDarkBgView.alpha = 0.0;
            self.shareButton.alpha = 1.0;
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
}

#pragma mark - On demand loading transitions
- (void)onDemandFadeDown {
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.timeLabelOnDemand.alpha = 0.0;
        self.progressView.alpha = 0.0;
        self.shareButton.alpha = 0.0;
    } completion:^(BOOL finished){
        
    }];
    
    if (!self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            self.queueBlurView.alpha = 1.0;
            self.queueDarkBgView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.queueBlurShown = YES;
        }];
    }
}

- (void)queueScrollEnded {
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.timeLabelOnDemand.alpha = 1.0;
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
        
        [[QueueManager shared] playItemAtPosition:newPage];
        self.queueCurrentPage = newPage;
        
    } else {
        [self.jogShuttle endAnimations];
        [self rebootOnDemandUI];
    }
}

- (void)rebootOnDemandUI {
    
    if (self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            
            self.queueBlurView.alpha = 0.0;
            self.queueDarkBgView.alpha = 0.0;
            self.progressView.alpha = 1.0;
            self.shareButton.alpha = 1.0;
            self.timeLabelOnDemand.alpha = 1.0;
            
        } completion:^(BOOL finished) {
            self.queueBlurShown = NO;
        }];
        
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
            event = @"menuSelectionDonate";
            NSString *urlStr = @"https://scprcontribute.publicradio.org/contribute.php?refId=iphone&askAmount=60";
            NSURL *url = [NSURL URLWithString:urlStr];
            [self decloakForMenu:YES];
            [[UIApplication sharedApplication] openURL:url];
            break;
        }
        case 4: {
            
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
    
    NSDate *ciCurrentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    NSTimeInterval ti = [[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:ciCurrentDate];
    
    Program *program = [[SessionManager shared] currentProgram];
    long ct = (long)CMTimeGetSeconds([AudioManager shared].audioPlayer.currentTime);
    if ( program || [AudioManager shared].currentAudioMode == AudioModeOnboarding ) {
        if ( [[AudioManager shared].audioPlayer rate] > 0.0 ) {
            if ( ct > 0 ) {
                [self.liveProgressViewController tick];
            }
        } else {
            NSLog(@"Trying to tick in non-playing state");
            return;
        }
    }
    
    
    if ( !self.menuOpen ) {
        if ( ti > 60 && ![[AudioManager shared] isStreamBuffering] ) {
            [self.liveDescriptionLabel setText:[NSString stringWithFormat:@"%@ BEHIND LIVE", [NSDate prettyTextFromSeconds:ti]]];
            self.previousRewindThreshold = [[AudioManager shared].audioPlayer.currentItem.currentDate timeIntervalSince1970];
        } else {
            //if ( !SEQ(self.liveDescriptionLabel.text,@"LIVE") ) {
            if ( [[SessionManager shared] sessionIsInRecess] ) {
                [self.liveDescriptionLabel setText:@"UP NEXT"];
            } else {
                [self.liveDescriptionLabel setText:@"LIVE"];
                self.dirtyFromRewind = NO;
            }
        }
    }
    
    if ( [AudioManager shared].currentAudioMode == AudioModeLive ) {
        if ( !self.menuOpen ) {
            if ( self.liveStreamView.layer.opacity < 1.0 ) {
                [UIView animateWithDuration:0.25 animations:^{
                    NSLog(@"Opacity was affected");
                    self.liveStreamView.layer.opacity = 1.0;
                }];
            }
        }
    }
    
    if (setForOnDemandUI) {
        [self.progressView pop_removeAllAnimations];
        
        if (CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]) > 0) {
            double currentTime = CMTimeGetSeconds([[[AudioManager shared].audioPlayer currentItem] currentTime]);
            double duration = CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]);
            
            [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:currentTime
                                                                     andDuration:duration]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressView setProgress:(currentTime / duration) animated:YES];
            });
        }
    } else {
        
        if ( !self.menuOpen ) {
            if ( !self.preRollOpen ) {
                if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
                    [self.liveProgressViewController show];
                }
                if ( self.initialPlay ) {
                    [self.liveProgressViewController show];
                }
            }
        }
    }
    
    // NOTE: basically used instead of observing player rate change to know when actual playback starts
    // .. for decloaking queue blur
    if ( [AudioManager shared].currentAudioMode == AudioModeOnDemand && self.queueLoading) {
        CMTime t = [AudioManager shared].audioPlayer.currentItem.currentTime;
        NSInteger s = CMTimeGetSeconds(t);
        if ( s > 0 || self.onDemandGateCount >= 2 ) {
            self.onDemandGateCount = 0;
            [self.queueBlurView setNeedsDisplay];
            [self.progressView setProgress:0.0 animated:NO];
            [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
                self.queueBlurView.alpha = 0.0;
                self.queueDarkBgView.alpha = 0.0;
                self.progressView.alpha = 1.0;
                self.shareButton.alpha = 1.0;
                self.onDemandPlayerView.alpha = 1.0;
            } completion:^(BOOL finished) {
                self.queueBlurShown = NO;
                self.queueLoading = NO;
                if ( [[AudioManager shared].audioPlayer rate] == 1.0 ) {
                    [self.jogShuttle endAnimations];
                }
            }];
        } else {
            self.onDemandGateCount++;
        }
    }
    
}

- (void)onSeekCompleted {
    // Make sure UI gets set to "Playing" state after a seek.
    if ( self.jogging ) {
        [self.jogShuttle endAnimations];
    }
}

- (void)interfere {
    [self.liveDescriptionLabel stopPulsating];
    self.jogging = YES;
    [self.liveDescriptionLabel fadeText:@"BUFFERING..."];
}

- (void)rollInterferenceText {
    NSString *fmt = @"%@";
    if ( [self.liveDescriptionLabel.text rangeOfString:@"..."].location != NSNotFound ) {
        fmt = @"%@   ";
    } else if ( [self.liveDescriptionLabel.text rangeOfString:@".."].location != NSNotFound ) {
        fmt = @"%@...";
    } else if ( [self.liveDescriptionLabel.text rangeOfString:@"."].location != NSNotFound ) {
        fmt = @"%@.. ";
    } else {
        fmt = @"%@.  ";
    }
    
    [self.liveDescriptionLabel fadeText:[NSString stringWithFormat:fmt,kBufferingText]];
}

- (void)onDemandAudioFailed {
    [self.jogShuttle endAnimations];
    self.timeLabelOnDemand.text = @"FAILED TO LOAD";
    
    
    
    [[[UIAlertView alloc] initWithTitle:@"Oops.."
                                message:@"We had some trouble loading that audio. Try again later or try a different show. Sorry."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
    
    [UIView animateWithDuration:0.15 animations:^{
        self.playPauseButton.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    } completion:^(BOOL finished) {
        [self goLive:NO];
    }];
    
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

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end