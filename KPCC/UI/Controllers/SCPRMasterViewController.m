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

static NSString *kRewindingText = @"REWINDING...";
static NSString *kForwardingText = @"GOING LIVE...";
static CGFloat kRewindGateThreshold = 8.0;
static CGFloat kDisabledAlpha = 0.15;

@interface SCPRMasterViewController () <AudioManagerDelegate, ContentProcessor, UINavigationControllerDelegate, UIViewControllerTransitioningDelegate, SCPRPreRollControllerDelegate, UIScrollViewDelegate>

@property BOOL initialPlay;
@property BOOL setPlaying;
@property BOOL seekRequested;
@property BOOL busyZoomAnim;
@property BOOL jogging;
@property BOOL setForLiveStreamUI;
@property BOOL setForOnDemandUI;
@property BOOL dirtyFromRewind;

@property IBOutlet NSLayoutConstraint *playerControlsTopYConstraint;
@property IBOutlet NSLayoutConstraint *playerControlsBottomYConstraint;
@property IBOutlet NSLayoutConstraint *rewindWidthConstraint;
@property IBOutlet NSLayoutConstraint *rewindHeightContraint;
@property IBOutlet NSLayoutConstraint *programTitleYConstraint;


- (NSDate*)cookDateForActualSchedule:(NSDate*)date;

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
            //[self playOrPauseTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            [self rewindFifteen];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
            [self fastForwardFifteen];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    pulldownMenu.delegate = self;
    [self.view addSubview:pulldownMenu];
    [pulldownMenu loadMenu];

    // Set up pre-roll child view controller.
    [self addPreRollController];

    // Fetch program info and update audio control state.
    [self updateDataForUI];

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
    [self.darkBgView setAlpha:0.0];

    // Initially flag as KPCC Live view
    setForLiveStreamUI = YES;

    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];

    MPSkipIntervalCommand *skipBackwardIntervalCommand = [rcc skipBackwardCommand];
    [skipBackwardIntervalCommand setEnabled:YES];
    [skipBackwardIntervalCommand addTarget:self action:@selector(skipBackwardEvent:)];
    skipBackwardIntervalCommand.preferredIntervals = @[@(15)];

    MPSkipIntervalCommand *skipForwardIntervalCommand = [rcc skipForwardCommand];
    skipForwardIntervalCommand.preferredIntervals = @[@(15)];  // Max 99
    [skipForwardIntervalCommand setEnabled:YES];
    [skipForwardIntervalCommand addTarget:self action:@selector(skipForwardEvent:)];

    MPRemoteCommand *pauseCommand = [rcc pauseCommand];
    [pauseCommand setEnabled:YES];
    [pauseCommand addTarget:self action:@selector(playOrPauseTapped:)];

    MPRemoteCommand *playCommand = [rcc playCommand];
    [playCommand setEnabled:YES];
    [playCommand addTarget:self action:@selector(playOrPauseTapped:)];

    self.jogShuttle = [[SCPRJogShuttleViewController alloc] init];
    self.jogShuttle.view = self.rewindView;
    self.jogShuttle.view.alpha = 0.0;
    [self.jogShuttle prepare];

    // Scroll view for audio queue
    self.queueScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.progressView.frame.origin.y - 64)];
    self.queueScrollView.backgroundColor = [UIColor greenColor];
    self.queueScrollView.alpha = 0.5f;
    self.queueScrollView.pagingEnabled = YES;
    self.queueScrollView.delegate = self;

    // Testing ...
    NSArray *colors = [NSArray arrayWithObjects:[UIColor redColor], [UIColor purpleColor], [UIColor blueColor], nil];
    for (int i = 0; i < [colors count]; i++) {
        CGRect frame;
        frame.origin.x = self.queueScrollView.frame.size.width * i;
        frame.origin.y = 0;
        frame.size = self.queueScrollView.frame.size;

        UIView *view = [[UIView alloc]initWithFrame:frame];
        view.backgroundColor = [colors objectAtIndex:i];
        view.alpha = 0.9f;
        [self.queueScrollView addSubview:view];
    }
    self.queueScrollView.contentSize = CGSizeMake(self.queueScrollView.frame.size.width * 3, self.queueScrollView.frame.size.height);
    [self.view insertSubview:self.queueScrollView belowSubview:self.playerControlsView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the current view to receive events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    if (self.menuOpen) {
        self.navigationItem.title = @"Menu";
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)addPreRollController {
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


# pragma mark - Actions

- (IBAction)initialPlayTapped:(id)sender {
    if (self.preRollViewController.tritonAd) {
        [self cloakForPreRoll:YES];
        [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
            [self.programTitleYConstraint setConstant:14];
            [self.initialControlsView setHidden:YES];
            initialPlay = YES;
        }];
    } else {
        [self primePlaybackUI];

        POPBasicAnimation *programTitleAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
        programTitleAnim.toValue = @(14);
        programTitleAnim.duration = .3;
        [self.programTitleYConstraint pop_addAnimation:programTitleAnim forKey:@"animateProgramTitleDown"];
        [self playStream];

        initialPlay = YES;
    }
}

- (IBAction)playOrPauseTapped:(id)sender {
    if (seekRequested) {
        seekRequested = NO;
    }

    if (![[AudioManager shared] isStreamPlaying]) {
        self.setPlaying = YES;

        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
        } else {
            [self playStream];
        }
    } else {
        self.setPlaying = NO;

        [self pauseStream];
    }
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

- (void)snapJogWheel {
    UIImage *pause = self.playPauseButton.imageView.image;
    CGFloat ht = pause.size.height; CGFloat wd = pause.size.width;
    [self.rewindHeightContraint setConstant:ht];
    [self.rewindWidthConstraint setConstant:wd];
    [self.playerControlsView layoutIfNeeded];
}

- (void)activateRewind:(RewindDistance)distance {
    
    
    [self snapJogWheel];
    [self.liveDescriptionLabel pulsate:kRewindingText color:nil];
    self.jogging = YES;
    
    self.rewindGate = YES;
    
    // Disable this until the stream separates from the beginning
    // of the program a litle bit
    self.liveRewindAltButton.userInteractionEnabled = NO;
    [self.liveRewindAltButton setAlpha:kDisabledAlpha];
    
    [self.jogShuttle.view setAlpha:1.0];
    [self.jogShuttle animateWithSpeed:1.0
                               hideableView:self.playPauseButton
                            direction:SpinDirectionBackward
                            withSound:YES
                           completion:^{

                               [[AudioManager shared].audioPlayer.currentItem cancelPendingSeeks];
                               [self.liveDescriptionLabel stopPulsating];
                               self.jogging = NO;
                               self.dirtyFromRewind = YES;
                               [self updateControlsAndUI:YES];
                               seekRequested = NO;
                               setPlaying = YES;
                               
                               [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                        self.rewindGate = NO;
                                   });
                               }];
                                
                                
                            }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        switch (distance) {
            case RewindDistanceBeginning:
                if (_currentProgram) {
#ifdef USE_LATENCY
                    NSDate *raw = _currentProgram.starts_at;
                    NSTimeInterval rawTI = [raw timeIntervalSince1970];
                    rawTI += [[AudioManager shared] latencyCorrection];
                    NSDate *cooked = [NSDate dateWithTimeIntervalSince1970:rawTI];
                    [[AudioManager shared] seekToDate:cooked];
#endif
                    if ( self.dirtyFromRewind ) {
                        [[AudioManager shared] specialSeekToDate:[self cookDateForActualSchedule:_currentProgram.starts_at]];
                    } else {

                        [[AudioManager shared] seekToDate:[self cookDateForActualSchedule:_currentProgram.starts_at]];
                    }
                }
                break;
            case RewindDistanceFifteen:
                [self rewindFifteen];
                break;
            case RewindDistanceThirty:
            default:
                break;
        }
        
        
    });
    
}

- (void)activateFastForward {
    [self snapJogWheel];
    
    self.jogging = YES;
    [self.liveDescriptionLabel pulsate:kForwardingText color:nil];
    [self.jogShuttle.view setAlpha:1.0];
    [self.jogShuttle animateWithSpeed:0.66
                         hideableView:self.playPauseButton
                            direction:SpinDirectionForward
                            withSound:NO
                           completion:^{
                               
                               [self.liveDescriptionLabel stopPulsating];
                               self.jogging = NO;
                               self.dirtyFromRewind = NO;
                               [self updateControlsAndUI:YES];
                               if ( !setPlaying ) {
                                   seekRequested = NO;
                                   setPlaying = YES;
                               }
                               
                               [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                   
                               }];
                           }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.66 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        [[AudioManager shared] forwardSeekLive];
        
    });
}

- (NSTimeInterval)rewindAgainstStreamDelta {
    AVPlayerItem *item = [[AudioManager shared].audioPlayer currentItem];
    NSTimeInterval current = [item.currentDate timeIntervalSince1970];
    
    if ( self.currentProgram ) {
        NSTimeInterval startOfProgram = [self.currentProgram.starts_at timeIntervalSince1970];
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
    
    [self activateFastForward];
    
}

- (IBAction)shareButtonTapped:(id)sender {
    if (self.onDemandProgram && self.onDemandEpUrl) {
        UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[self.onDemandEpUrl] applicationActivities:nil];
        controller.excludedActivityTypes = @[UIActivityTypeAirDrop];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (IBAction)showPreRollTapped:(id)sender {
    [self cloakForPreRoll:YES];
    [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {

    }];
}

# pragma mark - Audio commands

- (void)playStream {
    [[AudioManager shared] startStream];
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

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
}


# pragma mark - UI control

- (void)updateControlsAndUI:(BOOL)animated {

    // First set contents of background, live-status labels, and play button.
    [self setUIContents:animated];

    // Set positioning of UI elements.
    [self setUIPositioning];
}

- (void)setUIContents:(BOOL)animated {

    if ( self.jogging ) {
        return;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.1 animations:^{
            [self.playPauseButton setAlpha:0.0];

            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                if ( ![self uiIsJogging] ) {
                    [self.liveDescriptionLabel fadeText:@"LIVE"];
                }
                [self.rewindToShowStartButton setAlpha:0.0];
            } else {
                if ( ![self.liveDescriptionLabel.text isEqualToString:@"LIVE"] ) {
                    [self.liveDescriptionLabel fadeText:@"ON NOW"];
                }
                [self.liveRewindAltButton setAlpha:0.0];
                [self.backToLiveButton setAlpha:0.0];
                
            }

        } completion:^(BOOL finished) {
            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
            } else {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play"] forState:UIControlStateNormal];
            }

            // Leave this out for now.
            // [self scaleBackgroundImage];
        
            [UIView animateWithDuration:0.1 animations:^{
                [self.playPauseButton setAlpha:1.0];
                [self.jogShuttle.view setAlpha:0.0];
            }];
            
        }];

    } else {
        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            if ( ![self uiIsJogging] ) {
                [self.liveDescriptionLabel fadeText:@"LIVE"];
            }
            [self.rewindToShowStartButton setAlpha:0.0];
        } else {
            if ( ![self.liveDescriptionLabel.text isEqualToString:@"LIVE"] ) {
                [self.liveDescriptionLabel fadeText:@"ON NOW"];
            }
            [self.liveRewindAltButton setAlpha:0.0];
            [self.backToLiveButton setAlpha:0.0];
            
        }

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
        } else {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];
        }
    }
}

- (void)setUIPositioning {

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {

        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @(0.4);
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"dividerFadeInAnim"];

        POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeInAnim.toValue = @(1);
        
        if ( !self.rewindGate )
            [self.liveRewindAltButton.layer pop_addAnimation:genericFadeInAnim forKey:@"liveRewindFadeInAnim"];
        
        [self.backToLiveButton.layer pop_addAnimation:genericFadeInAnim forKey:@"backToLiveFadeInAnim"];

        POPBasicAnimation *genericFadeOutAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeOutAnim.toValue = @(0);
        [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeOutAnim forKey:@"rewindToStartFadeInAnim"];
        
    } else {
        if (!setPlaying) {
            if (!initialPlay) {
                POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
                genericFadeInAnim.toValue = @(1);
                [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeInAnim forKey:@"rewindToStartFadeInAnim"];

                POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
                dividerFadeAnim.toValue = @(0);
                [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"dividerFadeOutAnim"];
            }
        }
    }
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
    self.navigationItem.title = @"KPCC Live";

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

    // For testing audio queue...
    [self.prevEpisodeButton setHidden:YES];
    [self.nextEpisodeButton setHidden:YES];

    setForLiveStreamUI = YES;
}

- (void)setOnDemandUI:(BOOL)animated withProgram:(Program*)program andAudioChunk:(AudioChunk*)audioChunk {
    if (self.menuOpen) {
        [self decloakForMenu:NO];
    }

    self.navigationItem.title = @"Programs";
    [self.timeLabelOnDemand setText:@""];
    [self.progressView setProgress:0.0 animated:YES];

    // Update UILabels, content, etc.
    [self setDataForOnDemand:program andAudioChunk:audioChunk];

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

    // For testing audio queue...
    [self.prevEpisodeButton setHidden:NO];
    [self.nextEpisodeButton setHidden:NO];

    setForOnDemandUI = YES;
}

- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk {
    if (program != nil) {
        self.onDemandProgram = program;

        [[AudioManager shared] updateNowPlayingInfoWithAudio:audioChunk];

        [[DesignManager shared] loadProgramImage:program.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          [self.blurView setNeedsDisplay];
                                      }];

        [self.programTitleOnDemand setText:[program.title uppercaseString]];
    }

    if (audioChunk) {
        self.onDemandEpUrl = audioChunk.contentShareUrl;
        [self.episodeTitleOnDemand setText:audioChunk.audioTitle];
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

- (void)primePlaybackUI {
    POPBasicAnimation *initialControlsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    initialControlsFade.toValue = @(0);
    initialControlsFade.duration = 0.3;
    [self.initialPlayButton.layer pop_addAnimation:initialControlsFade forKey:@"initialControlsFadeAnimation"];

    POPBasicAnimation *bottomAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
    bottomAnim.toValue = @(50);
    bottomAnim.duration = .3;
    [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];

    POPBasicAnimation *topAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
    topAnim.toValue = @(CGRectGetMaxY(self.view.frame) - 245);
    topAnim.duration = .3;
    [self.playerControlsTopYConstraint pop_addAnimation:topAnim forKey:@"animateTopPlayControlsDown"];

    self.horizDividerLine.alpha = 0.4;
    POPBasicAnimation *scaleAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.duration = 1.0;
    [self.horizDividerLine.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
}

#pragma mark - Util
- (NSDate*)cookDateForActualSchedule:(NSDate *)date {
    NSTimeInterval supposed = [date timeIntervalSince1970];
    NSLog(@"Latency : %ld",(long)[[AudioManager shared] latencyCorrection]);
    
    long correction = [[AudioManager shared] latencyCorrection] > 0 ? [[AudioManager shared] latencyCorrection] : 0;
    NSTimeInterval actual = supposed + ((60 * 6) - correction);
    NSDate *actualDate = [NSDate dateWithTimeIntervalSince1970:actual];
    
    return actualDate;
}


#pragma mark - Menu control

- (void)cloakForMenu:(BOOL)animated {
    [self removeAllAnimations];
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

        // For testing audio queue...
        [self.prevEpisodeButton setHidden:YES];
        [self.nextEpisodeButton setHidden:YES];
    }

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"initialControlsViewFade"];
    }

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

        // For testing audio queue...
        [self.prevEpisodeButton setHidden:NO];
        [self.nextEpisodeButton setHidden:NO];
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
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"initialControlsViewFade"];
    }

    if ([[AudioManager shared] isStreamPlaying]) {
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
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
    }

    if (!initialPlay) {
        [self primePlaybackUI];
    }

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    //[self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];

    self.preRollOpen = YES;
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
    if (self.preRollOpen) {
        [self decloakForPreRoll:YES];
    }
    [[AudioManager shared] startStream];
}


#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSLog(@"didEndDecel");
}
-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"didScroll");
}


# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:{
            [[AudioManager shared] stopAllAudio];
            [self updateDataForUI];
            [self setLiveStreamingUI:YES];
            [self decloakForMenu:YES];
            [[AudioManager shared] startStream];
            break;
        }

        case 1: {
            Program *prog = self.currentProgram;
            if (setForOnDemandUI && self.onDemandProgram != nil) {
                prog = self.onDemandProgram;
            }

            SCPRProgramsListViewController *vc = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:prog];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
            
        case 2: {
            
            SCPRShortListViewController *slVC = [[SCPRShortListViewController alloc] initWithNibName:@"SCPRShortListViewController"
                                                                                              bundle:nil];
            [self.navigationController pushViewController:slVC animated:YES];
            break;
            
        }
        default: {
            [self decloakForMenu:YES];
            break;
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
    [self updateControlsAndUI:YES];
}

- (void)onTimeChange {
    
    if ( self.jogging ) {
        return;
    }
    
    NSAssert([NSThread isMainThread],@"This is not the main thread...");
    
    if ([[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:[[AudioManager shared] currentDate]] > 60 ) {
        
        NSTimeInterval ti = [[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:[[AudioManager shared] currentDate]];
        ti += [[AudioManager shared] latencyCorrection];
        
        NSInteger mins = (ti/60);

        [self.liveDescriptionLabel fadeText:[NSString stringWithFormat:@"%li MINUTES BEHIND LIVE", (long)mins]];
        [self.backToLiveButton setHidden:NO];
        
        
        if ( !self.rewindGate ) {
            if ( [self rewindAgainstStreamDelta] > kRewindGateThreshold ) {
                self.liveRewindAltButton.userInteractionEnabled = YES;
                [UIView animateWithDuration:0.33 animations:^{
                    [self.liveRewindAltButton setAlpha:1.0];
                }];
            } else {
                self.liveRewindAltButton.userInteractionEnabled = NO;
                [self.liveRewindAltButton setAlpha:kDisabledAlpha];
            }
        }
        
    } else {
        [self.liveDescriptionLabel fadeText:@"LIVE"];
        [self.backToLiveButton setHidden:YES];
        self.liveRewindAltButton.userInteractionEnabled = YES;
        self.dirtyFromRewind = NO;
        [UIView animateWithDuration:0.33 animations:^{
            [self.liveRewindAltButton setAlpha:1.0];
        }];
    }

    if (setForOnDemandUI) {
        [self.progressView pop_removeAllAnimations];

        if (CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]) > 0) {
            double currentTime = CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime]);
            double duration = CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]);

            [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:currentTime
                                                                     andDuration:duration]];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressView setProgress:(currentTime / duration) animated:YES];
            });
        }
    }
}

- (void)onSeekCompleted {
    // Make sure UI gets set to "Playing" state after a seek.
    if ( self.jogging ) {
        [self.jogShuttle endAnimations];
    } else {
        if (!setPlaying) {
            seekRequested = NO;            
            [self setUIPositioning];
            setPlaying = YES;
        }
    }
}


#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    if ([content count] == 0) {
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
